package main

Simulation :: struct {
    clear: proc(s: ^Simulation),
    pop: proc(s: ^Simulation) -> (t: Type_Kind),
    push: proc(s: ^Simulation, t: Type_Kind),
    stack: [dynamic]Type_Kind,
}

sim_push :: proc(s: ^Simulation, t: Type_Kind) {
    append(&s.stack, t)
}

sim_pop :: proc(s: ^Simulation) -> (t: Type_Kind) {
    return pop(&s.stack)
}

sim_clear :: proc(s: ^Simulation) {
    clear(&s.stack)
}

simulation_init :: proc(s: ^Simulation) {
    s.clear = sim_clear
    s.pop = sim_pop
    s.push = sim_push
    s.stack = make([dynamic]Type_Kind, 0, 16)
}
