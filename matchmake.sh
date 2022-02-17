#!/bin/bash
echo "This script will trigger a matchmaking with the given parameters and return a playerToken. This token can be used by the game server to communicate with our api."

file="matchmake.properties"

if [ -f "$file" ]
then
  echo "$file found."
  api_base=$(sed -rn 's/^api.base=([^\n]+)$/\1/p' $file)
  game_id=$(sed -rn 's/^game.id=([^\n]+)$/\1/p' $file)
  game_url=$(sed -rn 's/^game.url=([^\n]+)$/\1/p' $file)
  game_client_id=$(sed -rn 's/^game.client.id=([^\n]+)$/\1/p' $file)
  game_client_secret=$(sed -rn 's/^game.client.secret=([^\n]+)$/\1/p' $file)
  user_client_id=$(sed -rn 's/^user.client.id=([^\n]+)$/\1/p' $file)
  user_client_secret=$(sed -rn 's/^user.client.secret=([^\n]+)$/\1/p' $file)
  user_login=$(sed -rn 's/^user.login=([^\n]+)$/\1/p' $file)
  user_password=$(sed -rn 's/^user.password=([^\n]+)$/\1/p' $file)
  
  echo "Api Base          = " ${api_base}
  echo "Game Id           = " ${game_id}
  echo "Game URL          = " ${game_url}
  echo "Game ClientId     = " ${game_client_id}
  echo "Game ClientSecret = " ${game_client_secret}
  echo "User ClientId     = " ${user_client_id}
  echo "User ClientSecret = " ${user_client_secret}
  echo "User Login        = " ${user_login}
  echo "User Password     = " ${user_password}
else
  echo "$file not found."
  exit 1
fi

# Get accessToken for user to be used in matchmaking
accessTokenDirty=$(curl -s --location --request POST "${api_base}/auth/authorize" \
--header 'Content-Type: application/json' \
--data-raw "{
    \"grantType\": \"password\",
    \"username\": \"$user_login\",
    \"password\": \"$user_password\",
    \"clientId\": \"$user_client_id\",
    \"clientSecret\": \"$user_client_secret\"
}" | grep -oP '"accessToken": *\K"[^"]*"')
accessToken=${accessTokenDirty//\"/}
printf "accessToken for user:\n$accessToken\n\n"

# Now start matchmaking
ticketIdPairDirty=$(curl -s --location --request POST "${api_base}/matchmaking/search" \
--header "Authorization: Bearer $accessToken" \
--header 'Content-Type: application/json' \
--data-raw "{
    \"gameId\": \"$game_id\",
    \"gameMode\": \"1_vs_1\",
    \"denominationTier\": \"denomination_tier_0\"
}" | grep -oP '"ticketId": *\K"[^"]*"')
ticketId=${ticketIdPairDirty//\"/}
printf "ticketId for user: $ticketId\n\n"

# Check for matchmaking status and only return the playerToken, once the status is 'matched' or 'notMatched'
#clear
counter=0
sleepTime=5
for (( ; ; ))
do
    a=$(( counter * sleepTime ))
    printf "${a} sec.\twaiting for ticket status update for ticketId $ticketId [ hit CTRL+C to stop]\n"

    # Check for ticket status
    ticketStatusResponse=$(curl -s --location --request GET "${api_base}//matchmaking/ticket/$ticketId" --header "Authorization: Bearer $accessToken")
    tickerStatusDirty=$(echo $ticketStatusResponse | grep -oP '"status": *\K"[^"]*"')
    tickerStatus=${tickerStatusDirty//\"/}
    printf "Ticket Status: $tickerStatus\n"

    playerTokenDirty=$(echo $ticketStatusResponse | grep -oP '"playerToken": *\K"[^"]*"')
    playerToken=${playerTokenDirty//\"/}

    launchGame=$(echo Launch game: $game_url?playerToken=$playerToken)

    if [[ $tickerStatus == *matched* ]]
    then
        printf "Found a match - playerToken: $playerToken\n"
        echo $launchGame
        exit 0
    elif [[ $tickerStatus == *notMatched* ]]
    then
        printf "Not matched, you can play anyway - playerToken: $playerToken\n"
        echo $launchGame
        exit 0        
    fi

    ((counter++))
    sleep 5
done
