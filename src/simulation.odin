package main

Simulation :: struct {
    clear: proc(s: ^Simulation),
    pop: proc(s: ^Simulation) -> (t: Type_Kind_B),
    push: proc(s: ^Simulation, t: Type_Kind_B),
    stack: [dynamic]Type_Kind_B,
}

sim_push :: proc(s: ^Simulation, t: Type_Kind_B) {
    append(&s.stack, t)
}

sim_pop :: proc(s: ^Simulation) -> (t: Type_Kind_B) {
    return pop(&s.stack)
}

sim_clear :: proc(s: ^Simulation) {
    clear(&s.stack)
}

simulation_init :: proc(s: ^Simulation) {
    s.clear = sim_clear
    s.pop = sim_pop
    s.push = sim_push
    s.stack = make([dynamic]Type_Kind_B, 0, 16)
}
