import process/process
import process/process.{From, Pid, BarePid, ExitReason, Infinity, Milliseconds, TrapExit}
import process/supervisor/set_supervisor
import magpie/governor

pub fn spawn_link(server_supervisor) {
  let sup = set_supervisor.spawn_link(
    fn(_: Nil) { governor.spawn_link(server_supervisor) },
  )
  let _ = set_supervisor.start_child(sup, Nil)
  sup
}
