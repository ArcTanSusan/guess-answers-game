# Statement of Intended Behaviour

## Goal of the Application
The GuessingGame contract implements a trivia game where players can create questions, answer other players' questions, and compete for a prize pool.

## Main Flows

### Player Registration Flow

1. Players sign up by calling the signUp() function
2. Players provide a question and its hashed answer
3. Players must pay a minimum of 0.01 ETH to sign up
4. Each player receives a unique ID and their question is stored in the contract

### Question Answering Flow

1. Players can answer other players' questions by calling guessAnswer()
2. Players cannot answer their own questions
3. Players cannot answer the same question multiple times
4. Correct answers earn players points, which are tracked in their profile

### Game Conclusion Flow

1. The admin disables sign-ups to end the registration phase
2. The admin distributes the prize pool by calling distributeCash()
3. The player with the highest points receives the entire prize pool
4. The admin can reset the game to start a new round

### Emergency Management Flow

1. The admin can pause the contract in case of emergencies
2. When paused, all state-changing functions are disabled
3. The admin can unpause the contract to resume normal operation
4. The admin can reset the game state after the game has concluded

### Actors/Roles and Responsibilities

#### Admin (Game Host)

- Initialize the contract and set up the game parameters
- Control the game lifecycle (enable/disable sign-ups)
- Distribute prizes to winners
- Reset the game for new rounds
- Pause/unpause the contract in emergencies

#### Players

- Register for the game by providing a question and answer
- Pay an entry fee to join the game
- Answer other players' questions to earn points
- Potentially receive prize money if they have the highest score

### Access Restrictions

#### Admin-Only Functions

- `disableSignUp()`: Only the admin can end the registration phase
- `distributeCash()`: Only the admin can distribute the prize pool
- `resetGame()`: Only the admin can reset the game state
- `togglePause()`: Only the admin can pause/unpause the contract

#### Player-Only Functions

- `guessAnswer()`: Only registered players can answer questions
