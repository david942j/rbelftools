// Freestanding translation unit: no libc, so it cross-compiles to any target
// without a sysroot. Referencing externals and globals is what makes the
// object file carry a variety of relocations.
extern "C" int puts(const char *s);
extern int g_extern;
int g_common;
static int s_local = 5;
const char *g_str = "hello";
int (*g_fptr)(const char *);
static int helper(int n) { return n + s_local + g_common; }
extern "C" int entry(int n) {
  g_fptr = puts;
  puts(g_str);
  return helper(n) + g_extern;
}
