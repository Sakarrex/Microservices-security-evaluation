#!/bin/bash

TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt -s)

#Expect 403
curl https://mydomain.com/run

#Expect 401
curl --header "Authorization: Bearer deadbeef" https://mydomain.com/run

#Expect 200
curl --header "Authorization: Bearer $TOKEN" https://mydomain.com/run
