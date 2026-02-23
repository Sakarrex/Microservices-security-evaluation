#!/bin/bash

for i in $(seq 1 10); do curl  https://mydomain.com/cpu; done
#hey -n 1000 -c 10 https://mydomain.com/cpu