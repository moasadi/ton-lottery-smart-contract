import "@stdlib/deploy";
import "@stdlib/ownable";

struct Participant {
  addr: Address;
  tokenBought: Int as uint64;
}

message TokenPayout {
    value: Int as coins;
}

struct TokenPayoutResponse {
    token: String;
}

struct Winner {
   value: Int as coins;
   token: Int;
   address: Address;
}
struct WinnerDetails {
   value: Int as coins;
   token: Int;
   address: Address;
   timestamp: Int as uint64;
}
contract lottery with Deployable, Ownable {
  winner: Winner;
  owner: Address;
  balance: Int as uint256 = 0;
  tokenCost: Int as uint256 = ton("0.1");
  usersToken: map<Address, TokenPayoutResponse>;
  tokensUser: map<Int, Address>;
  tokensIndex: map<Int, Int>;
  tokenArrayLength: Int = 0;
  prizeClaimed: Bool = false;
  maxTickets: Int = 5; 
  winnerCount: Int = 0;
  pastWinners: map<Int, WinnerDetails>;

  init() {
    self.winner = Winner{value: 0, token: 0, address: address("EQCD39VS5jcptHL8vMjEXrzGaRcCVYto7HUn4bpAOg8xqB2N")};
    self.owner = sender();
  }

 receive(msg: TokenPayout) {
    let ctx: Context = context();
    
    require(ctx.value >= self.tokenCost + ton("0.02"), "Insufficient funds for token purchase and gas fees");

    let tokensCount: Int = 1; // Purchase one token at a time
    let totalCost: Int = self.tokenCost;
    let gasReserve: Int = ton("0.02");
    let remainingValue: Int = ctx.value - totalCost - gasReserve;
    
    let token: Int = random(111111, 999999);
    let sb: StringBuilder = beginString();
    let strToken: String = token.toString();
    if (self.usersToken.get(ctx.sender) != null) {
      let tokenPayoutResponse: TokenPayoutResponse = self.usersToken.get(ctx.sender)!!;
      sb.append(strToken);
      sb.append(",");
      sb.append(tokenPayoutResponse.token);
    } else {
      sb.append(strToken);
    }
    self.usersToken.set(ctx.sender, TokenPayoutResponse{token: sb.toString()});
    self.tokensUser.set(token, ctx.sender);
    self.tokenArrayLength = self.tokenArrayLength + 1;
    self.tokensIndex.set(self.tokenArrayLength, token);
    self.balance = self.balance + totalCost;

    send(SendParameters{
        to: ctx.sender,
        value: gasReserve,
        mode: SendPayGasSeparately,
        body: TokenPayoutResponse{token: strToken}.toCell()
    });

    if (remainingValue > 0) {
        send(SendParameters{
            to: ctx.sender,
            value: remainingValue,
            mode: SendPayGasSeparately + SendIgnoreErrors
        });
    }

    if (self.tokenArrayLength >= self.maxTickets) {
        self.runGame();
    }
  }

  fun runGame() {
    require(self.tokenArrayLength >= self.maxTickets, "Not enough tickets sold to run the game");
    let randomWinner: Int = random(1, self.tokenArrayLength);
    require(self.tokensIndex.get(randomWinner) != null, "Winner not found");
    let wonToken: Int = self.tokensIndex.get(randomWinner)!!;
    let wonUser: Address = self.tokensUser.get(wonToken)!!;
    self.winner = Winner{value: self.balance, token: wonToken, address: wonUser};
    self.winnerCount = self.winnerCount + 1;
    self.pastWinners.set(self.winnerCount, WinnerDetails{
      value: self.balance,
      token: wonToken,
      address: wonUser,
      timestamp: now()
    });
    self.clear();
  }

  receive("claim prize") {
    let ctx: Context = context();
    let reserveAmount: Int = ton("0.02"); 
    let amount: Int = self.winner.value - reserveAmount;
    require(amount > 0, "No active prize to claim");
    require(!self.prizeClaimed, "Prize has already been claimed");
    require(ctx.sender == self.winner.address, "Only the winner can claim the prize");
    send(SendParameters{
        to: self.winner.address,
        value: amount,
        mode: SendRemainingValue | SendIgnoreErrors
    });

    self.prizeClaimed = true;
    self.winner.value = amount;

    let sb: StringBuilder = beginString();
    sb.append("Prize claimed successfully. Amount sent: ");
    sb.append((amount / 1000000000).toString());
    sb.append(".");
    sb.append(((amount % 1000000000) / 100000000).toString()); 
    sb.append(" TON");
    sb.append(". The remaining ");
    sb.append((reserveAmount / 1000000000).toString());
    sb.append(" TON kept as reserve.");

    self.forward(ctx.sender, sb.toString().asComment(), true, null);
  }
  
  fun clear() {
    self.usersToken = emptyMap();
    self.tokensUser = emptyMap();
    self.tokensIndex = emptyMap();
    self.tokenArrayLength = 0;
    self.balance = 0;
    self.prizeClaimed = false;
  }

  get fun totalBalance(): Int {
    return self.balance;
  }

  get fun getUserTokens(): map<Address, TokenPayoutResponse> {
    return self.usersToken;
  }
  get fun getPastWinners(): map<Int, WinnerDetails>  {

   return self.pastWinners;
  }

  get fun getTicketsInfo(): String {
    let remainingTickets: Int = self.maxTickets - self.tokenArrayLength;
    let sb: StringBuilder = beginString();
    sb.append("{");
    sb.append("remainingTickets");
    sb.append(":");
    sb.append(remainingTickets.toString());
    sb.append(",");
    sb.append("totalTickets");
    sb.append(":");
    sb.append(self.maxTickets.toString());
    sb.append("}");
    return sb.toString();
  }

  get fun getLastWinner(): Winner {
    return self.winner;
  }
  get fun getTicketPrice(): String {
    return "0.1";
  }

 

}