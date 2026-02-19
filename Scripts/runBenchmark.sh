#!/bin/bash

#for i in $(seq 1 100); do curl --header "Content-Type: application/json"   --request POST   --data '{"num1":"1","num2":"2"}'   https://mydomain.com/api; done
hey -n 10000 -c 10 -m POST -H "Content-Type: application/json" -d '{"num1":"1","num2":"2"}' https://mydomain.com/api