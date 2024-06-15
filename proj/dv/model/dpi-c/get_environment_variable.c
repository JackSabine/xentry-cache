#include <svdpi.h>
#include <stdlib.h>

const char *get_environment_variable(const char *env_name) {
    return (const char *) getenv(env_name);
}
