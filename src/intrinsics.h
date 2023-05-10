#ifndef NLISP_INTRIRNSICS_H
#define NLISP_INTRIRNSICS_H

#ifdef DEBUG_MODE
    #define assert(expression) if(!(expression)) {*(int *)0 = 0;}
#else
    #define assert(expression)
#endif

#endif
