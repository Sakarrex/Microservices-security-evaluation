#!/bin/bash

#for i in $(seq 1 100); do curl  https://mydomain.com/run; done
hey -n 1000 -c 10 https://mydomain.com/run