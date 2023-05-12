#ifndef NLISP_INTRIRNSICS_H
#define NLISP_INTRIRNSICS_H

// TODO: Improve assertion for checking types, values, number of expressions, etc.
#define NASSERT(args, cond, format, ...)                                \
    if (!(cond)) {                                                      \
        nexp_t *error = nexp_new_error(format, ##__VA_ARGS__);          \
        nexp_delete(args);                                              \
        return error;                                                   \
    }

#endif
