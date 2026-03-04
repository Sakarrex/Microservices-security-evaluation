#!/bin/bash
TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt -s)

#for i in $(seq 1 100); do curl  https://mydomain.com/run; done
hey -n 1000 -c 10 -H "Authorization: Bearer $TOKEN" https://mydomain.com/run