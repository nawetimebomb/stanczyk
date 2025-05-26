package main

Simulation :: struct {
    pop: proc(s: ^Simulation) -> (t: Type_Kind_B),
    push: proc(s: ^Simulation, t: Type_Kind_B),
    values: [dynamic]Type_Kind_B,
}

sim_push :: proc(s: ^Simulation, t: Type_Kind_B) {
    append(&s.values, t)
}

sim_pop :: proc(s: ^Simulation) -> (t: Type_Kind_B) {
    return pop(&s.values)
}

simulation_init :: proc(s: ^Simulation) {
    s.pop = sim_pop
    s.push = sim_push
    s.values = make([dynamic]Type_Kind_B, 0, 16)
}
