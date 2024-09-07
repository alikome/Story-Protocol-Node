#!/usr/bin/env bash
set -euo pipefail

# Functions

mainMenu ()
{
    echo -e "\033[36m""Story Validator Tool V 1""\e[0m"
    echo "1 Install Story Node"
    echo "2 Update Story Node"
    echo "3 Create validator"
    echo "4 Get latest block height"
    echo "5 Get Validator dashboard link"
    echo "6 Get Validator Public and Private Keys"
    echo "q Quit"
}

installStoryGeth () # Story Geth install function
{
    echo "Getting Story Geth..."
    wget -qO story-geth.tar.gz $(curl -s https://api.github.com/repos/piplabs/story-geth/releases/latest | grep 'body' | grep -Eo 'https?://[^ ]+geth-linux-amd64[^ ]+' | sed 's/......$//')
    echo "Extracting and configuring Story Geth..."
    tar xf story-geth.tar.gz
    cp geth*/geth /bin
    rm -rf geth*/ | rm story-geth.tar.gz
            
}

installStoryConsensus () # Story Consensus install function
{      
    echo "Getting Story Consesus..."
    wget -qO story.tar.gz $(curl -s https://api.github.com/repos/piplabs/story/releases/latest | grep 'body' | grep -Eo 'https?://[^ ]+story-linux-amd64[^ ]+' | sed 's/......$//')
    echo "Extracting and configuring Story..."
    tar xf story.tar.gz
    cp story*/story /bin
    rm -rf story*/ | rm story.tar.gz
}

createStoryConsensusServiceFile ()
{
    echo "creating Stoy Consensus Service File"
    sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
        [Unit]
        Description=Story Consensus Client
        After=network.target

        [Service]
        User=root
        ExecStart=/bin/story run
        Restart=on-failure
        RestartSec=3
        LimitNOFILE=4096

        [Install]
        WantedBy=multi-user.target
EOF
    echo "Starting Story Consensus Service"
    sudo systemctl daemon-reload && \
    sudo systemctl start story && \
    sudo systemctl enable story
}

createStoryGethServiceFile ()
{
    echo "creating Stoy Geth Service File"
    sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
        [Unit]
        Description=Story Geth Client
        After=network.target

        [Service]
        User=root
        ExecStart=/bin/geth --iliad --syncmode full
        Restart=on-failure
        RestartSec=3
        LimitNOFILE=4096

        [Install]
        WantedBy=multi-user.target
EOF
    echo "Starting Story Geth Service"
    sudo systemctl daemon-reload && \
    sudo systemctl start story-geth && \
    sudo systemctl enable story-geth
}


while [[ 1 ]]
do
    echo
    mainMenu
    echo
    read -ep "Enter the number of the option you want: " CHOICE
    echo
    case "$CHOICE" in
        "1") # Install Story node
            installStoryConsensus
            installStoryGeth
            echo "Please enter your moniker"
            read varname
            story init --network iliad --moniker $varname
            createStoryConsensusServiceFile
            createStoryGethServiceFile
            echo "Adding Peers"
            sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$(curl -sS https://story-testnet-rpc.polkachu.com/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)\"/" $HOME/.story/story/config/config.toml
            echo "Restarting the services"
            sudo systemctl restart story
            sudo systemctl restart story-geth
            echo
            ;;
        "2") # Update Story Node
            sudo systemctl stop story
            sudo systemctl stop story-geth
            rm /bin/geth | rm /bin/story
            installStoryConsensus
            installStoryGeth
            echo "Starting the services"
            sudo systemctl start story
            sudo systemctl start story-geth
            echo
            ;;
        "3") # Create the validator
            echo "this will stake 0.5 IP to your validator, make sure you have some in your wallet"
            echo "please enter your private key"
            read -s key
            story validator create --stake 500000000000000000 --private-key $key
            echo
            ;;
        "4") # Get latest block height
            curl -s localhost:26657/status | jq .result.sync_info.latest_block_height
            echo
            ;;
        "5") # Get Validator dashboard link
            address=$(cat ~/.story/story/config/priv_validator_key.json | grep address | cut -d\" -f4)
            echo "https://testnet.story.explorers.guru/validator/$address"
            echo
            ;;    
        "6") # Get Validator Private Key
            story validator export --export-evm-key
            cat $HOME/.story/story/config/private_key.txt
            echo
            ;;  
        "q") # quit the script entirely
            exit
            ;;
    esac
done
