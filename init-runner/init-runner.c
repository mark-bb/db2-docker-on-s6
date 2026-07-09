#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

extern char** environ;

int main(int argc, char *argv[]) {

  setuid(0); setgid(0);
  execve("/init", &argv[0], environ);
  perror("execve");
  exit(EXIT_FAILURE); // Make sure to exit the child process if execve fails 
  exit(0);
}
