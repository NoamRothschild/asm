#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/shm.h>

int main() {
  // Attach to shared memory with ID 2
  void *shmaddr = shmat(2, NULL, 0);
  if (shmaddr == (void *)-1) {
    perror("shmat failed");
    return 1;
  }

  // Print lock status (first byte interpreted as boolean)
  printf("Locked? %s\n", *((unsigned char *)shmaddr) ? "true" : "false");

  // Print tail pointer (4 bytes starting at offset 1)
  void *tail_ptr = *((void **)(shmaddr + 1));
  printf("Tail ptr: %p\n", tail_ptr);

  // Print data
  printf("Data:\n");
  char *next = (char *)(shmaddr + 1 + 4 + 4);
  int i = 0;
  while (i != 3) {
    printf("- %s\n", (next));
    next += strlen(next) + 5;
    i++;
  }

  // Detach from shared memory
  if (shmdt(shmaddr) == -1) {
    perror("shmdt failed");
    return 1;
  }

  return 0;
}
