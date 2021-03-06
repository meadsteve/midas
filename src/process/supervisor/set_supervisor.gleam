// Other Possible name: Fleet Clone, Copy, Replica, Homogenious
import gleam/list
import gleam/option.{Some}
import process/process
import process/process.{From, Pid, BarePid, ExitReason, Infinity, Milliseconds, TrapExit}
import midas_utils

pub type Messages(m, c) {
  StartChild(From(Pid(m)), c)
  WhichChildren(From(List(Pid(m))))
  EXIT(BarePid, ExitReason)
}

fn pop(haystack, predicate, done) {
  case haystack {
    [] -> tuple(Error(Nil), list.reverse(done))
    [x, ..rest] -> case predicate(x) {
      True -> tuple(Ok(x), list.append(list.reverse(done), rest))
      False -> pop(rest, predicate, [x, ..done])
    }
  }
}

fn loop(receive, start_child, children) {
  case receive(Infinity) {
      // Could instead pass in a function that returns the right pid?
    Some(StartChild(from, config)) -> {
      let child = start_child(config)
      let children = [child, ..children]
      process.reply(from, child)
      loop(receive, start_child, children)
    }
    Some(WhichChildren(from)) -> {
      process.reply(from, list.reverse(children))
      loop(receive, start_child, children)
    }
    // TODO shouldn't be restarting servers
    // Unless do the cheat and map 500 live servers.
    Some(EXIT(down_pid, _)) -> {
      let predicate = fn(pid) { process.bare(pid) == down_pid }
      let tuple(_found, children) = pop(children, predicate, [])
      loop(receive, start_child, children)
    }
  }
}

fn init(receive, start_child) {
  process.process_flag(TrapExit(True))
  loop(receive, start_child, [])
}

pub fn spawn_link(start_child: fn(c) -> Pid(a)) -> Pid(Messages(a, c)) {
  process.spawn_link(init(_, start_child))
}

pub fn start_child(supervisor: Pid(Messages(m, c)), config: c) {
  process.call(supervisor, StartChild(_, config), Milliseconds(5000))
}

pub fn which_children(supervisor) {
  process.call(supervisor, WhichChildren(_), Milliseconds(5000))
}
