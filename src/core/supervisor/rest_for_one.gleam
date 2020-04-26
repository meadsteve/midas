import core/core.{Infinity}
import core/process.{Pid}
import core/process
import core/task
import core/supervisor

pub type ChildSpecs(a, b, c) {
    One(fn() -> Pid(a))
    Two(fn() -> Pid(a), fn(Pid(a)) -> Pid(b))
    Three(fn() -> Pid(a), fn(Pid(a)) -> Pid(b), fn(Pid(a), Pid(b)) -> Pid(c))
}

external fn exit(Pid(a)) -> Nil = "erlang" "exit"

type ChildState(a) {
    Running(Pid(a))
    Stopping(Pid(a))
    Stopped
    // Finished
}

fn do_stop(pid) {
    exit(pid)
    Stopping(pid)
}

fn stop3(children) {
    let tuple(child1, child2, child3) = children

    case child3 {
        Running(pid) -> tuple(child1, child2, do_stop(pid))
        Stopping(pid) -> tuple(child1, child2, child3)
        Stopped -> tuple(child1, child2, child3)
    }
}
fn stop2(children) {
    let tuple(child1, child2, child3) = children

    case child2 {
        Running(pid) -> tuple(child1, do_stop(pid), child3)
        Stopping(pid) -> tuple(child1, child2, child3)
        Stopped -> stop3(tuple(child1, child2, child3))
    }
}
fn stop1(children) {
    let tuple(child1, child2, child3) = children

    case child1 {
        Running(pid) -> tuple(do_stop(pid), child2, child3)
        Stopping(pid) -> tuple(child1, child2, child3)
        Stopped -> stop3(tuple(child1, child2, child3))
    }
}

fn start3(pid1, pid2, specs) {
    let tuple(_, _, fn3) = specs
    let pid3 = fn3(pid1, pid2)
    tuple(Running(pid1), Running(pid2), Running(pid3))
}

fn start2(pid1, specs) {
    let tuple(_, fn2, _) = specs
    let pid2 = fn2(pid1)
    start3(pid1, pid2, specs)
}

fn start1(specs) {
    let tuple(fn1, _, _) = specs
    let pid1 = fn1()
    start2(pid1, specs)
}

fn maybe_restart(specs, children) {
    let tuple(child1, child2, child3) = children

    case children {
        // All running
        tuple(Running(_), Running(_), Running(_)) -> children

        // Pid1 already running
        tuple(Running(pid1), Running(pid2), Stopped) -> start3(pid1, pid2, specs)
        tuple(Running(_), Running(_), _) -> stop3(children)

        // Pid2 already running
        tuple(Running(pid1), Stopped, Stopped) -> start2(pid1, specs)
        tuple(Running(_), _, _) -> stop2(children)

        // Pid3 already running
        tuple(Stopped, Stopped, Stopped) -> start1(specs)
        tuple(_, _, _) -> stop1(children)
    }
    // This would be a much simpler statement for all_for_one, If all running do nothing, if none running start, in all other cases start killing from one.
}

fn child_pid(child) {
    case child {
        Running(pid) | Stopping(pid) -> Ok(process.bare(pid))
        Stopped -> Error(Nil)
    }
}

fn loop(receive, specs, children) {
    case receive() {
        supervisor.Exit(pid) -> {
            let tuple(fn1, fn2, fn3) = specs
            let tuple(child1, child2, child3) = children

            let pid1 = child_pid(child1)
            let pid2 = child_pid(child2)
            let pid3 = child_pid(child3)

            let children = case Ok(pid) {
                p if p == pid1 -> tuple(Stopped, child2, child3)
                p if p == pid2 -> tuple(child1, Stopped, child3)
                p if p == pid3 -> tuple(child1, child2, Stopped)
            }

            let children = maybe_restart(specs, children)
            loop(receive, specs, children)
        }
    }
}

// Theres probably an more efficient no op pid that doesnt need to start a real process
fn spawn_dummy1(_) {
    task.spawn_link(fn(receive) {
        let task.Message(_) = receive(Infinity)
        Nil
    })
}
fn spawn_dummy2(_, _) {
    task.spawn_link(fn(receive) {
        let task.Message(_) = receive(Infinity)
        Nil
    })
}

pub fn start_link(init: fn() -> ChildSpecs(a, b, c)) {
    supervisor.spawn_link(fn(receive) {
        let specs = case init()  {
            One(fn1) -> tuple(fn1, spawn_dummy1, spawn_dummy2)
            Two(fn1, fn2) -> tuple(fn1, fn2, spawn_dummy2)
            Three(fn1, fn2, fn3) -> tuple(fn1, fn2, fn3)
        }

        let children = tuple(Stopped, Stopped, Stopped)
        loop(receive, specs, children)
    })
}

// fn init() {
//     tuple(fn() {
//         task.spawn_link(fn(receive) {
//             let task.Message(5) = receive(Infinity)
//             Nil
//         })
//     },
//     fn(previous) {
//         task.spawn_link(fn(receive) {
//             let task.Message(5) = receive(Infinity)
//             process.send(previous, 5)
//             Nil
//         })
//     })
// }
//
// fn demo() {
//     start_link(init)
// }
