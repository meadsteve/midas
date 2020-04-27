
pub type Wait {
    Infinity
    Milliseconds(Int)
}

// Need a type of Timeout that is equivalent to Option
// Can't be defined in 0.7 TODO move to master
pub type Timeout {
    Timeout
}

// WORKING WITH PROCESSES

pub type Pid(m) {
    Pid(Pid(m))
}

pub type ExitReason {
    Normal
    Kill
    // https://erlang.org/doc/reference_manual/errors.html#exit_reasons
    // Other types e.g. BadArith(Stack) can all be enumerated here.
}

type Receive(m) = fn(Wait) -> Result(m, Timeout)
type Run(m) = fn(Receive(m)) -> ExitReason

pub external fn spawn_link(Run(m)) -> Pid(m)
    = "process_native" "spawn_link"

pub external fn send(Pid(m), m) -> m
    = "erlang" "send"

pub external fn unsafe_self() -> Pid(m)
    = "erlang" "self"

pub fn self(_: Receive(m)) -> Pid(m) {
    unsafe_self()
}

// This can be typed because an untyped pid is only the result of a DOWN or EXIT Message
pub external fn exit(Pid(m), ExitReason) -> Bool
    = "erlang" "exit"

// WORKING WITH UNTYPED PROCESSES

pub type BarePid {
    BarePid(BarePid)
}

pub external fn bare(Pid(a)) -> BarePid
    = "process_native" "identity"

// WORKING WITH MONITORS AND REFERENCES

pub type Ref() {
    Ref(Ref)
}

type MonitorType {
    Process
}

external fn monitor(MonitorType, Pid(m)) -> Ref
    = "erlang" "monitor"

pub fn monitor_process(pid) {
    monitor(Process, pid)
}

pub type DemonitorOptions {
    Flush
}

pub external fn demonitor(Ref, List(DemonitorOptions)) -> Bool
    = "erlang" "demonitor"

// PROCESS FLAGS, WARNING:
// Can change the messages expected in a receive function

pub type ProcessFlag{
    TrapExit(Bool)
}

pub external fn process_flag(ProcessFlag) -> ProcessFlag
    = "process_native" "process_flag"

// CALL PROCESS

pub type From(r) {
    From(Ref, Pid(tuple(Ref, r)))
}

// Can check pid is self
// Need error because process could have terminated
// needs to be separate receive fn because we want to ignore exits and motiors from other pids
// Might be more expressive to "Gone/Slow", I can't have a separate Type that includes a Timout Branch
pub external fn receive_reply(Ref, Wait) -> Result(r, Timeout)
    = "process_native" "receive_reply"

pub fn call(pid: Pid(m), constructor: fn(From(r)) -> m, wait: Wait) -> Result(r, Timeout) {
    let reference = monitor_process(pid)
    let from = From(reference, unsafe_self())
    let _message = send(pid, constructor(from))
    receive_reply(reference, wait)
}

pub fn reply(from: From(r), message: r) {
    let From(reference, pid) = from
    send(pid, tuple(reference, message))
}

// Proc lib needs a start and init_ack function
// Will need an external receive ack

pub type OK {
    OK(OK)
}

pub external fn do_sleep(Int) -> OK
    = "timer" "sleep"
