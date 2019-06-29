//+------------------------------------------------------------------+
//|                                                 Boli_SL_BASE.mq5 |
//|                                                              Ido |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#property copyright "Ido"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property tester_indicator "SuperTrend_test2.ex5"
#property tester_indicator "ATR_Bands.ex5"
#property tester_indicator "Support_Resistance.ex5"
//+------------------------------------------------------------------+
//| input parameters                                                 |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES timeFrame=PERIOD_D1;   // Time frame
input int         period=1100;               //bb Period
input int         STperiod=2800;             //ST period
input int         bb_Shift = 0;              //bb shift
input double      bb_Deviation = 2;          //bb deviation
input int         lot_factor = 5;            //precent to invest
input double      portfilioLimit = 5000000;  //max amount of protfilio to enter position
input double      atr_band_factor=0.35;
input double      InpR=1.5;                  //R ratio for entry
//+------------------------------------------------------------------+
//| global parameters                                                |
//+------------------------------------------------------------------+
double super_trend1[];
double super_trend2[];
double atr_top_band[];
double atr_bot_band[];
double atr_mid_band[];
double bb_Bottom_Array[];
double bb_Top_Array[];
double p_close,p_high,p_low
   ,pp_close,pp_high,pp_low;
double orderPrice=0;
double lastLots=0;

int EA_Magic=12345;
int orderAmount=0;

CTrade trade;
CPositionInfo position;
MqlTick latest_price;
MqlTradeRequest mrequest={0};
MqlTradeResult  mresult={0};
MqlTradeCheckResult check;
MqlRates mrate[];

//indicator handlers
int superTrend;
int superTrend2;
int atrBands;
int bars;
int bb,atr;
int sr;
bool orderProcecced=true;
bool isModified=false;
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
   superTrend=iCustom(_Symbol,_Period,"SuperTrend_test2",timeFrame,0.65,3);
   if(superTrend==INVALID_HANDLE)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
   superTrend2=iCustom(_Symbol,_Period,"SuperTrend_test2",timeFrame,2,10);
   if(superTrend2==INVALID_HANDLE)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
   atrBands=iCustom(_Symbol,_Period,"ATR_Bands",timeFrame,4,atr_band_factor);
   if(atrBands==INVALID_HANDLE)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
   sr=iCustom(_Symbol,_Period,"Support_Resistance",PERIOD_W1);
   if(sr==INVALID_HANDLE)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
   ChartIndicatorAdd(ChartID(),0,sr);
   ChartIndicatorAdd(ChartID(),0,atrBands);
   ChartIndicatorAdd(ChartID(),0,superTrend);
   ChartIndicatorAdd(ChartID(),0,superTrend2);
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
   if(CopyBuffer(atrBands,1,0,2,atr_top_band)<0)
     {
      ResetLastError();
      return;
     }
   if(CopyBuffer(atrBands,2,0,2,atr_bot_band)<0)
     {
      ResetLastError();
      return;
     }
   if(CopyBuffer(atrBands,0,0,2,atr_mid_band)<0)
     {
      ResetLastError();
      return;
     }
   if(CopyBuffer(superTrend,1,0,2,super_trend1)<0)
     {
      ResetLastError();
      return;
     }
   if(CopyBuffer(superTrend2,1,0,2,super_trend2)<0)
     {
      ResetLastError();
      return;
     }
   bool Buy_opened=false;  // variable to hold the result of Buy opened position
   bool Sell_opened=false; // variables to hold the result of Sell opened position

   double bb_Bottom_Value=NormalizeDouble(bb_Bottom_Array[1],_Digits);
   double bb_Top_Value=NormalizeDouble(bb_Top_Array[0],_Digits);

   double bb_Mid_Value=(bb_Top_Value+bb_Bottom_Value)/2; //50%
   double bb_Top_Half_Value=(bb_Top_Value+bb_Mid_Value)/2; //75%
   double bb_Bot_Half_Value=(bb_Mid_Value+bb_Bottom_Value)/2; //25%   

   double atr_Bottom_Value=NormalizeDouble(atr_bot_band[1],_Digits);
   double atr_Top_Value=NormalizeDouble(atr_top_band[1],_Digits);
   double atr_Mid_Value=NormalizeDouble(atr_mid_band[1],_Digits);

   double st_value=NormalizeDouble(super_trend1[1],_Digits);
   double st_value2=NormalizeDouble(super_trend2[1],_Digits);

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

   int _bars=Bars(_Symbol,_Period);
//----------------------------------------------------------------------------------------------------------------------
//--enter Positions conditions

//crossed bot boli upwards 
   bool Buy_Condition_1=(latest_price.ask>bb_Bottom_Value && latest_price.ask<bb_Mid_Value && p_close<bb_Bottom_Value);
//crossed top boli downwards
   bool Sell_Condition_1=(latest_price.bid<bb_Top_Value && latest_price.bid>bb_Mid_Value && p_close>bb_Top_Value);

//-----------------------------------------------------------STRATEGY-----------------------------------------------------------
//-------------check for position-------------------
//
//   if(_bars!=bars)
//     {
//      if(PositionSelect(_Symbol)==false)
//        {
//         isModified=false;
//
//         //Green SUPERTREND
//         if(st_value==1 && st_value2==1)
//           {
//            if(Buy(calculateLotSize(),true,atr_Bottom_Value,atr_Top_Value))
//              {
//               Comment("Buy position successful");
//              }
//            else Comment("Buy position unsuccessful");
//           }
//         //else if(Sell_Condition_1 && R_Multiple(atr_Top_Value,atr_Top_Value,Ask))
//         //  {
//         //   if(Buy(calculateLotSize(),false,atr_Bottom_Value,atr_Top_Value))
//         //     {
//         //      Comment("Buy position successful");
//         //     }
//         //   else Comment("Buy position unsuccessful");
//         //  }
//         else
//         //RED SUPERTREND
//         if(st_value==0 && st_value2==0)
//           {
//
//            if(Sell(calculateLotSize(),true,atr_Top_Value,atr_Bottom_Value))
//              {
//               Comment("Buy position successful");
//              }
//            else Comment("Buy position unsuccessful");
//            //else if(Buy_Condition_1 && R_Multiple(atr_Bottom_Value,atr_Top_Value,Bid))
//            //  {
//            //   if(Sell(calculateLotSize(),true,atr_Top_Value,atr_Bottom_Value))
//            //     {
//            //      Comment("Buy position successful");
//            //     }
//            //   else Comment("Buy position unsuccessful");
//            //  }
//
//           }
//        }
//     }

//   +------------------------------------------------------------------+
//  |CHECK FOR EXIT CONDITIONS|
//   +------------------------------------------------------------------+
//if(PositionSelect(_Symbol)==true)
//  {
//   if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
//     {
//      if(p_close>bb_Bot_Half_Value && atr_Mid_Value>bb_Bot_Half_Value && p_close<bb_Mid_Value)
//        {
//         trade.PositionModify(position.Ticket(),atr_Bottom_Value,bb_Mid_Value);
//        }
//      if(p_close<bb_Top_Half_Value && atr_Mid_Value<bb_Top_Half_Value && p_close>bb_Mid_Value)
//        {
//         trade.PositionModify(position.Ticket(),p_low,bb_Top_Value);
//        }
//     }
//   else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
//     {
//      if(p_close>bb_Bot_Half_Value && atr_Mid_Value>bb_Bot_Half_Value && p_close<bb_Mid_Value)
//        {
//         trade.PositionModify(position.Ticket(),p_high,bb_Bottom_Value);
//        }
//      if(p_close<bb_Top_Half_Value && atr_Mid_Value<bb_Top_Half_Value && p_close>bb_Mid_Value)
//        {
//         trade.PositionModify(position.Ticket(),atr_Top_Value,bb_Mid_Value);
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

      mrequest.sl = NormalizeDouble(sl,_Digits);
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
      mrequest.sl=NormalizeDouble(sl,_Digits);
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
bool R_Multiple(double takeProfit,double stopLoss,double entry)
  {
   double distance_to_target=MathAbs(entry-takeProfit);
   double distance_to_stop=MathAbs(entry-stopLoss);
   double div;
   if(distance_to_stop==0) { div=0; }
   else { div=distance_to_target/distance_to_stop; }
//Alert("R: ",div);

   if(div > InpR) return true;
   else return false;

  }
//+------------------------------------------------------------------+
