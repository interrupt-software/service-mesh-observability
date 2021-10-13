#!/bin/bash

export SERVER0=$(terraform output -json | jq -r '.server_seeds.value[0]')
export SERVER1=$(terraform output -json | jq -r '.server_seeds.value[1]')
export SERVER2=$(terraform output -json | jq -r '.server_seeds.value[2]')

#### Consul Servers

rm -f init-consul-server.sh
cp -p init-consul-server.tpl init-consul-server.sh

sed -i'' -e 's/SERVER0/'"$SERVER0"'/g' init-consul-server.sh
sed -i'' -e 's/SERVER1/'"$SERVER1"'/g' init-consul-server.sh
sed -i'' -e 's/SERVER2/'"$SERVER2"'/g' init-consul-server.sh

rm -f init-consul-server.sh-e

#### Nomad Servers

rm -f init-nomad-server.sh
cp -p init-nomad-server.tpl init-nomad-server.sh

sed -i'' -e 's/SERVER0/'"$SERVER0"'/g' init-nomad-server.sh
sed -i'' -e 's/SERVER1/'"$SERVER1"'/g' init-nomad-server.sh
sed -i'' -e 's/SERVER2/'"$SERVER2"'/g' init-nomad-server.sh

rm -f init-nomad-server.sh-e

#### Consul Clients

rm -f init-consul-client.sh
cp -p init-consul-client.tpl init-consul-client.sh

sed -i'' -e 's/SERVER0/'"$SERVER0"'/g' init-consul-client.sh
sed -i'' -e 's/SERVER1/'"$SERVER1"'/g' init-consul-client.sh
sed -i'' -e 's/SERVER2/'"$SERVER2"'/g' init-consul-client.sh


rm -f init-consul-client.sh-e

#### Nomad Clients

rm -f init-nomad-client.sh
cp -p init-nomad-client.tpl init-nomad-client.sh

sed -i'' -e 's/SERVER0/'"$SERVER0"'/g' init-nomad-client.sh
sed -i'' -e 's/SERVER1/'"$SERVER1"'/g' init-nomad-client.sh
sed -i'' -e 's/SERVER2/'"$SERVER2"'/g' init-nomad-client.sh

rm -f init-nomad-client.sh-e