#include <iostream>
#include <chrono>
#include <cstdlib>
#include <cstring>

int main() {
    const int iterations = 1000;
    const int size = 10000;
    // Accumulate allocations — don't free until end
    int** blocks = (int**)malloc(iterations * sizeof(int*));
    
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; i++) {
        blocks[i] = (int*)malloc(size * sizeof(int));
        memset(blocks[i], i & 0xFF, size * sizeof(int)); // force actual page faults
    }
    auto end = std::chrono::high_resolution_clock::now();
    
    
    for (int i = 0; i < iterations; i++) free(blocks[i]);
    free(blocks);
    
    double ms = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << "Done in " << ms << "ms\n";
    std::cout << "Peak alloc: ~" << (iterations * size * sizeof(int) / 1024 / 1024) << "MB\n";
}