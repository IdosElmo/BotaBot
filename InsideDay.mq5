//+------------------------------------------------------------------+
//|                                                    InsideDay.mq5 |
//|                                                     Ido Elmaliah |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ido Elmaliah"
#property link      "https://www.mql5.com"
#property version   "1.00"

#property tester_indicator "Indicators\InsideBar.ex5"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| global parameters                                 |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;
MqlTick latest_price;
MqlTradeRequest mrequest={0};
MqlTradeResult  mresult={0};
MqlTradeCheckResult check;
MqlRates mrate[];

double upperInside[];
double lowerInside[];
double insideBuff[];
double lot=1;

bool isBreachedUP=false;
bool isBreachedDOWN=false;
bool isInsideDay=false;
double upperDailyBound;
double lowerDailyBound;

double orderPrice=0;
double takeLimit = 0;
double stopLoss=0;
double dailyBoundClose;

double p_close; //previous candle's close.
double p_high; //previous candle's high.
double p_low;  //previous candle's low.
int EA_Magic=12345;

int handler;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   handler=iCustom(_Symbol,_Period,"InsideBar");
   if(handler==INVALID_HANDLE)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
   ChartIndicatorAdd(ChartID(),0,handler);
   EventSetTimer(86400);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
//IndicatorRelease(handler);
   EventKillTimer();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//    

   ZeroMemory(mrequest);
   Comment("");
   ArraySetAsSeries(mrate,true);
   ArraySetAsSeries(insideBuff,true);
//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }
//copy upper limit array
   if(CopyBuffer(handler,4,0,5,insideBuff)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }

   bool Buy_opened=false;  // variable to hold the result of Buy opened position
   bool Sell_opened=false; // variables to hold the result of Sell opened position

   if(PositionSelect(_Symbol)==true)
     { // we have an opened position
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         Buy_opened=true;  //It is a Buy
        }
      else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
        {
         Sell_opened=true; // It is a Sell
        }
     }

   p_close= mrate[2].close;
   p_high = mrate[2].high;
   p_low=mrate[2].low;

//you are inside bar
   if(insideBuff[1]==1 && !isInsideDay)
     {
      upperDailyBound = p_high;
      lowerDailyBound = p_low;
      isInsideDay=true;
     }
//low breach and close inside
   else if(insideBuff[1]==2 && isInsideDay)
     {
      isBreachedDOWN=true;
      takeLimit= upperDailyBound;
      stopLoss = lowerDailyBound - 2*(lowerDailyBound - mrate[1].low);
     }
//high breach and close inside
   else if(insideBuff[1]==3 && isInsideDay)
     {
      takeLimit= lowerDailyBound;
      stopLoss = upperDailyBound + 2*(mrate[1].high - upperDailyBound);
      isBreachedUP=true;
     }
   else if(insideBuff[1]==EMPTY_VALUE) isInsideDay=false;

   if(isBreachedDOWN && !Buy_opened && !Sell_opened)
     {
      Buy(lot);
      isBreachedDOWN=false;
      isInsideDay=false;
     }
   if(isBreachedUP && !Sell_opened && !Buy_opened)
     {
      Sell(lot);
      isBreachedUP=false;
      isInsideDay=false;
     }
   ChartRedraw();

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseCurrentPositions()
  {
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current position
      if(position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(position.Symbol()==Symbol())
            trade.PositionClose(position.Ticket()); // close a position by the specified symbol
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| calculate Lot Size                                               |
//+------------------------------------------------------------------+

/*
double calculateLotSize(){
   if(orderAmount > 0){
      lastLots *=lot_multi;
      return lastLots;
   }
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > portfilioLimit) balance = portfilioLimit;
   double res = NormalizeDouble(balance/lot_factor,1);
   res = (double)round(res);
   res = res/10;
   lastLots = res;
   return res;
}
*/

//+------------------------------------------------------------------+
//| BUY                                                              |
//+------------------------------------------------------------------+
bool Buy(double lots)
  {
   mrequest.action = TRADE_ACTION_DEAL;                                   // immediate order execution
   mrequest.price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);                 // latest ask price
   mrequest.symbol = _Symbol;                                             // currency pair
   mrequest.volume = lots;                                                // number of lots to trade
   mrequest.magic = EA_Magic;                                             // Order Magic Number
   mrequest.type = ORDER_TYPE_BUY;                                        // Buy Order
   mrequest.type_filling = ORDER_FILLING_FOK;                             // Order execution type
   mrequest.deviation=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*2;
   mrequest.sl=stopLoss;
   mrequest.tp=takeLimit;          // Deviation from current price
//--- send order

   if(OrderCheck(mrequest,check))
     {
      if(OrderSend(mrequest,mresult))
        {
         // get the result code
         if(mresult.retcode==10009 || mresult.retcode==10008)
           {                  //Request is completed or order placed
            Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
            orderPrice=mrequest.price;
           }
         else
           {
            Alert("The Buy order request could not be completed -error:",GetLastError());
            ResetLastError();
            return false;
           }
        }
     }

/*
   OrderSend(mrequest,mresult);
   // get the result code
   if(mresult.retcode==10009 || mresult.retcode==10008){                  //Request is completed or order placed
      Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
   }
   else{
      Alert("The Buy order request could not be completed -error:",GetLastError());
      ResetLastError();           
      return false;
   }
   */

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| SELL                                                             |
//+------------------------------------------------------------------+
bool Sell(double lots)
  {
   mrequest.action = TRADE_ACTION_DEAL;                                   // immediate order execution
   mrequest.price = SymbolInfoDouble(_Symbol,SYMBOL_BID);                 // latest ask price
   mrequest.symbol = _Symbol;                                             // currency pair
   mrequest.volume = lots;                                                // number of lots to trade
   mrequest.magic = EA_Magic;                                             // Order Magic Number
   mrequest.type = ORDER_TYPE_SELL;                                       // Sell Order
   mrequest.type_filling = ORDER_FILLING_FOK;                             // Order execution type
   mrequest.deviation=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*2;         // Deviation from current price
   mrequest.sl=stopLoss;                                         // Stop Loss
   mrequest.tp= takeLimit;
//--- send order

   if(OrderCheck(mrequest,check))
     {
      if(OrderSend(mrequest,mresult))
        {
         // get the result code
         if(mresult.retcode==10009 || mresult.retcode==10008)
           {                  //Request is completed or order placed
            Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
            orderPrice=mrequest.price;
           }
         else
           {
            Alert("The Sell order request could not be completed -error:",GetLastError());
            ResetLastError();
            return false;
           }
        }
     }

/*
   OrderSend(mrequest,mresult);
   // get the result code
   if(mresult.retcode==10009 || mresult.retcode==10008){                  //Request is completed or order placed
      Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
   }
   else{
      Alert("The Sell order request could not be completed -error:",GetLastError());
      ResetLastError();           
      return false;
   }
   */
   return true;
  }
//+------------------------------------------------------------------+
