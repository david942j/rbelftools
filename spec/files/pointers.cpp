// Many pointers to force the relative relocations into a bitmap rather than
// leaving each of them an address of its own.
static int slots[128];
int *const table[128] = {
#define TEN(n) &slots[n], &slots[n + 1], &slots[n + 2], &slots[n + 3], &slots[n + 4], \
               &slots[n + 5], &slots[n + 6], &slots[n + 7], &slots[n + 8], &slots[n + 9],
  TEN(0) TEN(10) TEN(20) TEN(30) TEN(40) TEN(50) TEN(60) TEN(70) TEN(80) TEN(90)
  TEN(100) TEN(110)
  &slots[120], &slots[121], &slots[122], &slots[123],
  &slots[124], &slots[125], &slots[126], &slots[127]
};

int main() { return *table[0]; }
