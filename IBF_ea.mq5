//+------------------------------------------------------------------+
//|                                                    InsideDay.mq5 |
//|                                                     Ido Elmaliah |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ido Elmaliah"
#property link      "https://www.mql5.com"
#property version   "1.60"

#property tester_indicator "IBF_indicator.ex5"
#include <Trade\Trade.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input double risk_percent=2; //percent to risk
input double InpR=1.5; //R ratio for entry
input double InpEvolvingR=0.4; //Evo-R value
input double longFactor=1; //Factor for long
input double shortFactor=1; //Factor for short
input bool ER=false; //Evo-R switch (false = off)
input bool moveSL=false; //Move SL (false = off)
//+------------------------------------------------------------------+
//| global parameters                                                |
//+------------------------------------------------------------------+
CTrade trade;
CAccountInfo accountInfo;
CPositionInfo position;
MqlTick latest_price;
MqlTradeRequest mrequest={0};
MqlTradeResult  mresult={0};
MqlTradeCheckResult check;
MqlRates mrate[];
datetime Time[];

double countWin=0;
double countLoss=0;

//Indicator buffers
double upperInside[];
double lowerInside[];
double insideBuff[];
double atrValues[];
int EA_Magic=12345;

bool isBreachedUP=false;
bool isBreachedDOWN=false;
bool isInsideDay=false;
bool changeStopLoss=false;
bool Buy_opened=false;
bool Sell_opened=false;
bool flag=false; //flag median calculation
double upperDailyBound;
double lowerDailyBound;
double positionSize=0;
double takeLimit=0;
double stopLoss=0;   //stop loss
double orderPrice=0;
double equity=0;
double pp_close; //previous previous candle's close.
double pp_high; //previous previous candle's high.
double pp_low;  //previous previous candle's low.
double median=0; //mid point between limits (for stop loss change)
double newSL =0;
int bars;
int handler; //custom inside bar handler
int atr;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   handler=iCustom(_Symbol,_Period,"IBF_indicator");
   if(handler==INVALID_HANDLE)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
   ChartIndicatorAdd(ChartID(),0,handler);

   atr=iATR(_Symbol,PERIOD_CURRENT,14);
   if(atr==INVALID_HANDLE)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
//ChartIndicatorAdd(ChartID(),0,atr);
   bars=Bars(_Symbol,_Period);
//EventSetTimer(86400);
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
//EventKillTimer();
//ObjectsDeleteAll(0,-1,-1);
   ScanClosedTrades();
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
   ArraySetAsSeries(atrValues,true);

//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }
//copy upper limit array
   if(CopyBuffer(handler,5,0,3,insideBuff)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }

   if(CopyBuffer(atr,0,0,3,atrValues)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }

   pp_close= mrate[2].close;
   pp_high = mrate[2].high;
   pp_low=mrate[2].low;
   int _bars=Bars(_Symbol,_Period);
   checkOpenPoisitions();

   if(_bars!=bars)
     {
      if(PositionSelect(_Symbol)==true)
        {
         isBreachedDOWN=false;
         isBreachedUP=false;
         isInsideDay=false;

         if(!flag) { flag=true; median=(lowerDailyBound+upperDailyBound)/2; }

         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            //50% function
            //check evolving R for take profit 
            orderPrice=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            //double quarter = (currentSL + median) / 2;

            if(mrate[1].close>median)
              {
               if(moveSL && !changeStopLoss)
                 {
                  newSL=mrate[1].low;
                  trade.PositionModify(position.Ticket(),newSL,currentTP);
                  changeStopLoss=true;
                 }

               if(ER && R_Multiple(currentTP,currentSL,orderPrice,true))
                 {
                  trade.PositionClose(position.Ticket());
                  changeStopLoss=false;
                 }

              }
           }

         else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
           {
            orderPrice=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            //double quarter = median / 2;

            if(mrate[1].close<median)
              {
               if(moveSL && !changeStopLoss)
                 {
                  newSL=mrate[1].high;
                  trade.PositionModify(position.Ticket(),newSL,currentTP);
                  changeStopLoss=true;
                 }
               if(ER && R_Multiple(currentTP,currentSL,orderPrice,true))
                 {

                  trade.PositionClose(position.Ticket());
                  changeStopLoss=false;
                 }
              }
           }
         bars++;
        }
     }

//check only if there are no positions
   if(PositionSelect(_Symbol)==false)
     {
      flag=false;
      //you are inside bar
      if((insideBuff[1]==1 || insideBuff[1]==0) && !isInsideDay)
        {
         upperDailyBound = pp_high;
         lowerDailyBound = pp_low;
         isInsideDay=true;
        }
      //low breach and close inside
      else if(insideBuff[1]==2 && isInsideDay)
        {
         orderPrice=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double prevATRvalue=atrValues[1];

         takeLimit=upperDailyBound;
         stopLoss=lowerDailyBound -prevATRvalue*longFactor;
         //newSL = mrate[1].high;
         if(R_Multiple(takeLimit,stopLoss,orderPrice,false))
           {
            isBreachedDOWN=true;
            isInsideDay=false;
           }
         else isInsideDay=false;
        }
      //high breach and close inside
      else if(insideBuff[1]==3 && isInsideDay)
        {
         orderPrice=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double prevATRvalue=atrValues[1];

         takeLimit=lowerDailyBound;
         stopLoss=upperDailyBound+prevATRvalue*shortFactor;
         //newSL = mrate[1].low;
         if(R_Multiple(takeLimit,stopLoss,orderPrice,false))
           {
            isBreachedUP=true;
            isInsideDay = false;
           }
         else isInsideDay=false;

        }
      else if(insideBuff[1]==4)
        {
         isInsideDay=true;
        }
      else if(insideBuff[1]==EMPTY_VALUE)
        {
         isInsideDay=false;
        }

     }
   else if(flag)
     {
      if((insideBuff[1]==1 || insideBuff[1]==0) && !isInsideDay)
        {
         upperDailyBound = pp_high;
         lowerDailyBound = pp_low;
         isInsideDay=true;
        }
     }

   if(isBreachedDOWN && !Buy_opened && !Sell_opened)
     {
      Buy();
      isBreachedDOWN=false;
      isInsideDay=false;
      changeStopLoss=false;
     }
   if(isBreachedUP && !Sell_opened && !Buy_opened)
     {
      Sell();
      isBreachedUP=false;
      isInsideDay=false;
      changeStopLoss=false;
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
//| calculate Lot Size based on percentege.                                               |
//+------------------------------------------------------------------+

/*
double calculateLotSize()
  {
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double res=NormalizeDouble((balance/100000)*percent,1);
   return res;
  } */
//+------------------------------------------------------------------+
//| BUY                                                              |
//+------------------------------------------------------------------+
bool Buy()
  {
   mrequest.action = TRADE_ACTION_DEAL;                                   // immediate order execution
   mrequest.price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);                 // latest ask price
   mrequest.symbol = _Symbol;                                             // currency pair
   mrequest.magic = EA_Magic;                                             // Order Magic Number
   mrequest.type = ORDER_TYPE_BUY;                                        // Buy Order
   mrequest.type_filling = ORDER_FILLING_FOK;                             // Order execution type
   mrequest.deviation=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*2;
   mrequest.sl=NormalizeDouble(stopLoss,_Digits);
   mrequest.tp=takeLimit;          // Deviation from current price
   equity=accountInfo.Equity();
   positionSize=equity *(risk_percent/100)/((mrequest.price-mrequest.sl)*100000);
   mrequest.volume=NormalizeDouble(positionSize,2);                                 // number of lots to trade

   printStats(mrequest.price,mrequest.sl,mrequest.tp);
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
bool Sell()
  {
   mrequest.action = TRADE_ACTION_DEAL;                                   // immediate order execution
   mrequest.price = SymbolInfoDouble(_Symbol,SYMBOL_BID);                 // latest ask price
   mrequest.symbol = _Symbol;                                             // currency pair                                               // number of lots to trade
   mrequest.magic = EA_Magic;                                             // Order Magic Number
   mrequest.type = ORDER_TYPE_SELL;                                       // Sell Order
   mrequest.type_filling = ORDER_FILLING_FOK;                             // Order execution type
   mrequest.deviation=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*2;         // Deviation from current price
   mrequest.sl=NormalizeDouble(stopLoss,_Digits);                                                  // Stop Loss
   mrequest.tp= takeLimit;
   equity=accountInfo.Equity();
   positionSize=equity *(risk_percent/100)/((mrequest.sl-mrequest.price)*100000);
   mrequest.volume=NormalizeDouble(positionSize,2);                 // number of lots to trade

   printStats(mrequest.price,mrequest.sl,mrequest.tp);
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

bool R_Multiple(double takeProfit,double lowerLimit,double entry,bool isEvolving)
  {
   double distance_to_target=MathAbs(entry-takeProfit);
   double distance_to_stop=MathAbs(entry-lowerLimit);
   double div;
   if(distance_to_stop==0) { div=0; }
   else { div=distance_to_target/distance_to_stop; }
//Alert("R: ",div);

   if(!isEvolving)
     {

      if(div > InpR) return true;
      else return false;
     }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   else
     {
      if(div < InpEvolvingR) return true;
      else return false;
     }
  }
//+------------------------------------------------------------------+
void printStats(double entryPrice,double SL,double TP)
  {
   double distance_to_target=MathAbs(entryPrice-TP);
   double distance_to_stop=MathAbs(entryPrice-SL);
   double div;
   if(distance_to_stop==0) { div=0; }
   else { div=distance_to_target/distance_to_stop; }

   Alert("High Limit: ",NormalizeDouble(upperDailyBound,_Digits));
   Alert("Low Limit: ",NormalizeDouble(lowerDailyBound,_Digits));
   Alert("Median(50%): ",(upperDailyBound+lowerDailyBound)/2);
   Alert("Equity: ",NormalizeDouble(equity,_Digits));
   Alert("Distance to target: ",NormalizeDouble(distance_to_target,_Digits));
   Alert("Distance to stop: ",NormalizeDouble(distance_to_stop,_Digits));
   Alert("R-ratio: ",NormalizeDouble(div,_Digits));
   Alert("Position Size - in LOT: ",NormalizeDouble(positionSize,_Digits));
   Alert("Entry Price: ",NormalizeDouble(entryPrice,_Digits));
   Alert("Stop Loss: ",SL);
   Alert("Take Profit: ",TP);

  }
//+------------------------------------------------------------------+
void checkOpenPoisitions()
  {
   Buy_opened=false;  // variable to hold the result of Buy opened position
   Sell_opened=false; // variables to hold the result of Sell opened position
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
  }
//+------------------------------------------------------------------+
void ScanClosedTrades()
  {
   HistorySelect(0,TimeCurrent());

   ulong  ticket=0;
   double profit;
   uint   dealsTotal=HistoryDealsTotal();
//--- Loop for tracking wins losses and lot sizes for trading

   for(uint i=1; i<dealsTotal; i++)
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
     {
      if((ticket=HistoryDealGetTicket(i))>0)
        {
         profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);

        }

      if(profit<0)
        {
         countLoss++;
        }
      else if(profit>0)countWin++;

     }
   double ratio=countWin/(countWin+countLoss);
   Alert("Win: ",countWin);
   Alert("Loss: ",countLoss);
   Alert("ratio: ",NormalizeDouble(ratio,4));
  }
//+------------------------------------------------------------------+
