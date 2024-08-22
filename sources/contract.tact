import "@stdlib/deploy";
import "@stdlib/ownable";
struct Participant {
  addr: Address;
  tokenBought: Int as uint64;
}
message TokenPayout{
    value: Int as coins;
}
struct TokenPayoutResponse {
    token: String;
}
struct Winner{
   value: Int as coins;
   token: Int;
   address: Address;
}

contract lottery with Deployable, Ownable {
  winner: Winner;
  owner: Address;
  balance: Int as uint256 =0;
  tokenCost:Int as uint256= ton("0.1");
  usersToken: map<Address, TokenPayoutResponse>;
  tokensUser: map<Int,Address>;
  tokensIndex: map<Int,Int>;
  tokenArrayLength:Int=0;
  prizeClaimed: Bool = false;
  init(){
    self.winner=Winner{value:0,token:0,address:address("EQCD39VS5jcptHL8vMjEXrzGaRcCVYto7HUn4bpAOg8xqB2N")};
    self.owner = sender();
  }

  receive(msg:TokenPayout){
    let ctx: Context = context();
    
    require(context().value >= self.tokenCost, "Insufficient funds for token purchase");

    let tokensCount: Int = context().value / self.tokenCost;
    let totalCost: Int = tokensCount * self.tokenCost;
    let remainingValue: Int = context().value - totalCost;
    
    let token: Int =random(111111,999999);
    let sb: StringBuilder = beginString();
    let strToken:String=token.toString();
    if(self.usersToken.get(ctx.sender)!=null){
      let tokenPayoutResponse: TokenPayoutResponse=self.usersToken.get(ctx.sender)!!;
      sb.append(strToken);
      sb.append(",");
      sb.append(tokenPayoutResponse.token);
    }else{
      sb.append(strToken);
    }
    self.usersToken.set(ctx.sender,TokenPayoutResponse{token:sb.toString()});
    self.tokensUser.set(token,ctx.sender);
    self.tokenArrayLength=self.tokenArrayLength+1;
    self.tokensIndex.set(self.tokenArrayLength,token);
    self.balance = self.balance + totalCost;

   
    self.forward(ctx.sender, TokenPayoutResponse{ token:token.toString()}.toCell(), true, null);
    if (remainingValue > 0) {
        send(SendParameters{
            to: ctx.sender,
            value: remainingValue,
            mode: SendPayGasSeparately + SendIgnoreErrors
        });
    }
  }
  receive("run game"){
   let ctx: Context = context();
   require(ctx.sender==self.owner,"Owner only access to run the game!");
   let randomWinner: Int=random(0,self.tokenArrayLength);
   require(self.tokensIndex.get(randomWinner)!=null,"winner not found");
   let wonToken: Int = self.tokensIndex.get(randomWinner)!!;
   let wonUser: Address= self.tokensUser.get(wonToken)!!;
   self.winner=Winner{value:self.balance,token:wonToken,address:wonUser};
   self.clear();
  }
receive("claim prize") {
    let ctx: Context = context();
    let reserveAmount: Int = ton("0.02"); 
    let amount:Int= self.winner.value - reserveAmount;
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
    sb.append(".");
    

    self.forward(ctx.sender, sb.toString().asComment(), true, null);
}
  
  fun clear() {
    self.usersToken=emptyMap();
    self.tokensUser=emptyMap();
    self.tokensIndex=emptyMap();
    self.tokenArrayLength=0;
    self.balance=0;
    self.prizeClaimed=false;
  }

  get fun totalBalance(): Int {
    return self.balance;
  }

  get fun getUserTokens():map<Address, TokenPayoutResponse>{
  
   return self.usersToken;
  }

  get fun getLastwinner():Winner{
    return self.winner;
  }

  
}