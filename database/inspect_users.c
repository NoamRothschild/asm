#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/shm.h>
#include <sys/types.h>

void printSHA1(u_int32_t *digest);
void printByte(unsigned char byte);

int main() {
  printf("shmid: ");
  int shmid = 0;
  scanf("%d", &shmid);
  getchar();

  // Attach to shared memory with ID 3
  void *shmaddr = shmat(shmid, NULL, 0);
  if (shmaddr == (void *)-1) {
    perror("shmat failed");
    return 1;
  }
  void *addrcpy = shmaddr;

  // Print lock status (first byte interpreted as boolean)
  printf("Locked? %s\n", *((unsigned char *)shmaddr) ? "true" : "false");
  addrcpy++;

  int8_t usr_id = 0;
  printf("| ID | UNAME      | PWD                                          | "
         "TOKEN                                        | ADMIN?     |\n");
  while (usr_id++ == *((int8_t *)addrcpy)) {
    printf("| %-2d | %-10s | ", *((int8_t *)addrcpy), (char *)(addrcpy + 1));
    addrcpy += 256;                    // ID && UNAME
    printSHA1((u_int32_t *)(addrcpy)); // PWD
    printf("| ");
    addrcpy += 20;
    printSHA1((u_int32_t *)(addrcpy)); // TOKEN
    printf("| ");
    addrcpy += 20;
    printByte(*((char *)addrcpy++)); // ADMIN?
    printf(" | \n");
  }
  printf("Finished execution.\n");
  printf("Last: %d, %d", usr_id, *((int8_t *)addrcpy));

  // Detach from shared memory
  if (shmdt(shmaddr) == -1) {
    perror("shmdt failed");
    return 1;
  }

  return 0;
}

void printSHA1(u_int32_t *digest) {
  int swapped = 0, num = 0;
  for (int i = 0; i < 5; i++) {
    num = digest[i];
    // converting to big endian
    swapped = ((num >> 24) & 0xff) |      // move byte 3 to byte 0
              ((num << 8) & 0xff0000) |   // move byte 1 to byte 2
              ((num >> 8) & 0xff00) |     // move byte 2 to byte 1
              ((num << 24) & 0xff000000); // byte 0 to byte 3
    printf("%08x ", swapped);
  }
}

void printByte(unsigned char byte) {
  printf("0b");
  for (int i = 0; i < 8; i++) {
    printf("%d", (byte >> (7 - i)) & 1);
  }
}
