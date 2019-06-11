//+------------------------------------------------------------------+
//|                                                Boli_M15_MAIN.mq5 |
//|                                                              Ido |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#property copyright "Ido"
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| input parameters                                  |
//+------------------------------------------------------------------+

input int         period=1100;               //bb Period
input int         STperiod=2800;             //ST period
input int         bb_Shift = 0;              //bb shift
input double      bb_Deviation = 2;          //bb deviation
input int         lot_factor = 5;            //precent to invest
input double      lot_multi = 2;             //amount of lot to to rebuy, x*lots 
input int         maxRebuy = 0;              //maximum amount of rebuys
input double      portfilioLimit = 5000000;  //max amount of protfilio to enter position
input double      stopLoss=0.01;
input double      takeProfit=0.03;

//+------------------------------------------------------------------+
//| global parameters                                                |
//+------------------------------------------------------------------+
double bb_Bottom_Array[];
double bb_Top_Array[];
double p_close,p_high,p_low
   ,pp_close,pp_high,pp_low;
double orderPrice=0;
double lastLots=0;

int EA_Magic=12345;
int orderAmount=0;
int stop_loss_counter=0;

bool orderProcecced=true;
bool moveSL=false;
bool moveSLAgain=false;
CTrade trade;
CPositionInfo position;
MqlTick latest_price;
MqlTradeRequest mrequest={0};
MqlTradeResult  mresult={0};
MqlTradeCheckResult check;
MqlRates mrate[];

bool flagLongOnce=false;
bool flagShortOnce=false;
int superTrend;
int bars;
int bb,atr;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   bars=Bars(_Symbol,_Period);
   bb=iBands(_Symbol,_Period,period,bb_Shift,bb_Deviation,PRICE_CLOSE);
   if(bb<0)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
   superTrend=iCustom(_Symbol,_Period,"SuperTrend",STperiod);
   if(superTrend==INVALID_HANDLE)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
   ChartIndicatorAdd(ChartID(),0,superTrend);
   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release our indicator handles
//IndicatorRelease(bb);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   ZeroMemory(mrequest);
   Comment("");
   ArraySetAsSeries(bb_Bottom_Array,true);
   ArraySetAsSeries(bb_Top_Array,true);
   ArraySetAsSeries(mrate,true);
   double Ask,Bid;
   ulong Spread;
   Ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   Bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   Spread=SymbolInfoInteger(Symbol(),SYMBOL_SPREAD);
//--- Output values in three lines
   Comment(StringFormat("Show prices\nAsk = %G\nBid = %G\nSpread = %d\nOrder Amount = %d",Ask,Bid,Spread,orderAmount));
//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol,latest_price))
     {
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return;
     }

//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }

//define EA current candle, 3 candles, save in array
   if(CopyBuffer(bb,2,0,2,bb_Bottom_Array)<0)
     {
      Alert("Error copying Moving Average indicator buffer - error:",GetLastError());
      ResetLastError();
      return;
     }
   if(CopyBuffer(bb,1,0,2,bb_Top_Array)<0)
     {
      Alert("Error copying Moving Average indicator buffer - error:",GetLastError());
      ResetLastError();
      return;
     }
   bool Buy_opened=false;  // variable to hold the result of Buy opened position
   bool Sell_opened=false; // variables to hold the result of Sell opened position

   double bb_Bottom_Value=NormalizeDouble(bb_Bottom_Array[0],_Digits);
   double bb_Top_Value=NormalizeDouble(bb_Top_Array[0],_Digits);

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

// Copy the bar close,high and low prices for the previous bar prior to the current bar, that is Bar 1
   p_close= mrate[1].close;
   p_high = mrate[1].high;
   p_low=mrate[1].low;

   pp_close= mrate[2].close;
   pp_high = mrate[2].high;
   pp_low=mrate[2].low;
//----------------------------------------------------------------------------------------------------------------------
//--enter Positions conditions

   double bb_mid_value=(bb_Top_Value+bb_Bottom_Value)/2; //50%

   double bb_top_half=(bb_Top_Value+bb_mid_value)/2; //75%
   double bb_bot_half=(bb_mid_value+bb_Bottom_Value)/2; //25%   

   double bb_top_quarter=(bb_Top_Value+bb_top_half)/2; //87.5%
   double bb_bot_quarter=(bb_Bottom_Value+bb_bot_half)/2; //12.5%

   double bb_top_three_quarter = (bb_mid_value + bb_top_half)/2;
   double bb_bot_three_quarter = (bb_mid_value + bb_bot_half)/2;

   bool set_stop_short=(latest_price.ask<bb_top_half);
   bool set_stop_long =(latest_price.bid>bb_bot_half);

   bool Buy_Condition_1=(latest_price.ask<bb_Bottom_Value); //crossed bot boli downwards
   bool Buy_Condition_2=(latest_price.ask>bb_Bottom_Value && latest_price.ask<bb_mid_value); //crossed bot boli upwards

   bool Short_Condition_1=(latest_price.bid>bb_Top_Value); //crossed top boli upwards  
   bool Short_Condition_2=(latest_price.bid<bb_Top_Value && latest_price.bid>bb_mid_value); //crossed top boli downwards

   bool exit_Buy_Condition=(latest_price.bid>bb_mid_value && latest_price.bid<bb_Top_Value);
   bool exit_Sell_Condition=(latest_price.ask<bb_mid_value && latest_price.ask>bb_Bottom_Value);

   bool stop_long=(Buy_opened && bb_Top_Value<=orderPrice);
   bool stop_short=(Sell_opened && bb_Bottom_Value>=orderPrice);
   int _bars=Bars(_Symbol,_Period);

//-----------------------------------------------------------STRATEGY-----------------------------------------------------------

//-------------check for long position-------------------

   if(_bars!=bars)
     {
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      //buy condition
      if(Buy_Condition_1 && !flagLongOnce)
        {
         if(!flagLongOnce)
           {
            flagLongOnce=true;
           }

        }
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      //-------------check for short position-------------------
      if(Short_Condition_1 && !flagShortOnce)
        {
         if(!flagShortOnce)
           {
            flagShortOnce=true;
           }
        }
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      if(PositionSelect(_Symbol)==false)
        {
         if(flagLongOnce && p_close<bb_Bottom_Value && pp_close<bb_Bottom_Value)
           {
            if(Buy_Condition_2)
              {
               flagLongOnce=false;
               moveSL=false;
               moveSLAgain=false;
               if(Buy(calculateLotSize(),false,0,bb_mid_value))
                 {
                  Comment("Buy position successful");
                 }
               else Comment("Buy position unsuccessful");
              }
           }
         else if(flagShortOnce && p_close>bb_Top_Value && pp_close>bb_Top_Value)
           {
            if(Short_Condition_2)
              {
               flagShortOnce=false;
               moveSL=false;
               moveSLAgain=false;
               if(Sell(calculateLotSize(),false,0,bb_mid_value))
                 {
                  Comment("Buy position successful");
                 }
               else Comment("Buy position unsuccessful");
              }
           }
        }

     }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(PositionSelect(_Symbol)==true)
     {
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         if(exit_Buy_Condition)
           {
            flagLongOnce=false;
            CloseCurrentPositions(true);
           }
         if(set_stop_long && p_close>bb_bot_half)
           {
            if(!moveSL)
              {
               moveSL=true;
               moveSLAgain=true;
               trade.PositionModify(position.Ticket(),bb_bot_quarter,bb_mid_value);
              }
            if(moveSLAgain && p_close>bb_bot_three_quarter)
              {
               trade.PositionModify(position.Ticket(),bb_bot_half,bb_mid_value);
               moveSLAgain=false;
              }
           }
        }
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
        {
         if(exit_Sell_Condition)
           {
            flagShortOnce=false;
            CloseCurrentPositions(true);
           }
         if(set_stop_short && p_close<bb_top_half)
           {
            if(!moveSL)
              {
               moveSL=true;
               moveSLAgain=true;
               trade.PositionModify(position.Ticket(),bb_top_quarter,bb_mid_value);
              }
            if(moveSLAgain && p_close<bb_top_three_quarter)
              {
               trade.PositionModify(position.Ticket(),bb_top_half,bb_mid_value);
               moveSLAgain=false;
              }
           }
        }
     }

//---this is not the first order...
//if(!isReady)
//  {
//   if(Buy_opened)
//     {
//      if(set_stop_long)
//        {
//         if(!moveSL)
//           {
//            moveSL=true;
//            isReadyAgain=false;
//            trade.PositionModify(position.Ticket(),mrate[1].low,bb_mid_value);
//           }
//        }
//     }
//   else
//   if(Sell_opened)
//     {
//      if(set_stop_short)
//        {
//         if(!moveSL)
//           {
//            moveSL=true;
//            isReadyAgain=false;
//            trade.PositionModify(position.Ticket(),mrate[1].high,bb_mid_value);
//           }
//        }
//     }
//  }
  }
//+------------------------------------------------------------------+
//| BUY                                                              |
//+------------------------------------------------------------------+
bool Buy(double lots,bool haveLimits,double sl,double tp)
  {
   mrequest.action = TRADE_ACTION_DEAL;                                   // immediate order execution
   mrequest.price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);                 // latest ask price
   mrequest.symbol = _Symbol;                                             // currency pair
   mrequest.volume = lots;                                                // number of lots to trade
   mrequest.magic = EA_Magic;                                             // Order Magic Number
   mrequest.type = ORDER_TYPE_BUY;                                        // Buy Order
   mrequest.type_filling = ORDER_FILLING_FOK;                             // Order execution type
   mrequest.deviation=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*2;         // Deviation from current price
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(haveLimits)
     {

      mrequest.sl = NormalizeDouble(mrequest.price - sl,_Digits);
      mrequest.tp = NormalizeDouble(tp,_Digits);
     }
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
            orderAmount++;
            orderProcecced=true;
           }
         else
           {
            Alert("The Buy order request could not be completed -error:",GetLastError());
            ResetLastError();
            return false;
           }
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
//| SELL                                                             |
//+------------------------------------------------------------------+
bool Sell(double lots,bool haveLimits,double sl,double tp)
  {
   mrequest.action = TRADE_ACTION_DEAL;                                   // immediate order execution
   mrequest.price = SymbolInfoDouble(_Symbol,SYMBOL_BID);                 // latest ask price
   mrequest.symbol = _Symbol;                                             // currency pair
   mrequest.volume = lots;                                                // number of lots to trade
   mrequest.magic = EA_Magic;                                             // Order Magic Number
   mrequest.type = ORDER_TYPE_SELL;                                       // Sell Order
   mrequest.type_filling = ORDER_FILLING_FOK;                             // Order execution type
   mrequest.deviation=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*2;           // Deviation from current price
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(haveLimits)
     {
      mrequest.sl=NormalizeDouble(mrequest.price+sl,_Digits);
      mrequest.tp=NormalizeDouble(tp,_Digits);
     }
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
            orderAmount++;
            orderProcecced=true;
           }
         else
           {
            Alert("The Sell order request could not be completed -error:",GetLastError());
            ResetLastError();
            return false;
           }
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
//| calculate Lot Size                                               |
//+------------------------------------------------------------------+
double calculateLotSize()
  {
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(balance>portfilioLimit)
     {
      balance=portfilioLimit;
     }
   double res=NormalizeDouble((balance/100000)*lot_factor,2);
   lastLots=res;
   return res;
  }
//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+

bool CloseCurrentPositions(bool x)
  {

   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current position
      if(position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(position.Symbol()==Symbol())
            trade.PositionClose(position.Ticket(),SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)); // close a position by the specified symbol

   bool Buy_opened=false;  // variable to hold the result of Buy opened position
   bool Sell_opened=false; // variables to hold the result of Sell opened position
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(PositionSelect(_Symbol)==true)
     { // we have an opened position
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         Buy_opened=true;  //It is a Buy
        }
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
        {
         Sell_opened=true; // It is a Sell
        }
     }
   if(Sell_opened || Buy_opened) return false;
//isSetForFirstPosition=false;
   orderAmount=0;
   return true;
  }

//+------------------------------------------------------------------+
