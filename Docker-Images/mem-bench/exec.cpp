#include<iostream>
#include<chrono>
#include<cstdlib>

int main() {
    srand(time(0));
    const int iterations = 1000000;
    int size = rand()%10000 + 100; // Random size between 1 and 100
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; i++) {
        int* block = (int*)malloc(size * sizeof(int));
        block[0] = i;
        free(block);
    }

    auto end = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << "Done in " << ms << "ms\n";
    std::cout << "Avg per alloc/free: " << (ms * 1e6 / iterations) << "ns\n";
}