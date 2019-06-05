//+------------------------------------------------------------------+
//|                                                    InsideBar.mq5 |
//|                                                     Ido Elmaliah |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ido Elmaliah"
#property link      "https://www.mql5.com"
#property version   "1.30"

/*
   this indicator show every inside bar.
   inside bar will be marked with 2 arrows (blue and red) showing that
   this bar is an inside bar to the previous bar.
   
   also there are 2 buffers that show the mother bar high and low as limits.
   
   if there are breaches, those will be marked with thumbs up and thumbs down respectively.
   inside will be marked as FALSE after a breach as occoured.
   important:
   
      insideBuffer is a buffer to help indicate the state
      of our bar respectively to the indicator using integers:
      EMPTY_VALIE = nothing
      1 = inside bar
      2 = low breach after seeing inside bar
      3 = high breach after seeing inside bar
      4 = maintaining inside bar status without any changes.
*/

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots 4
//#property indicator_type1 DRAW_ARROW
//#property indicator_type2 DRAW_ARROW
#property indicator_color1 clrBlue
#property indicator_color2 clrRed
#property indicator_color3 clrChocolate
#property indicator_color4 clrDarkOrange
#property indicator_style1 STYLE_SOLID
#property indicator_style2 STYLE_SOLID
#property indicator_style3 STYLE_SOLID
#property indicator_style4 STYLE_SOLID
#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 2
#property indicator_width4 2


//---- global parameters
ENUM_TIMEFRAMES timeframe=PERIOD_D1;   //Period to find Inside Bar
string timeframe_name="Daily";
string buyName="BuyArrow";
string sellName="SellArrow";
int countBUY=0;
int countSELL=0;
//---- buffers ----//
double HighBuff[];
double LowBuff[];
double lineHighBuff[];
double lineLowBuff[];
double insideBuffer[];
bool isInsideDay=false;
double upperDailyBound;
double lowerDailyBound;
#define DATA_LIMIT = 5
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,HighBuff,INDICATOR_DATA);
   SetIndexBuffer(1,LowBuff,INDICATOR_DATA);
   SetIndexBuffer(2,lineHighBuff,INDICATOR_DATA);
   SetIndexBuffer(3,lineLowBuff,INDICATOR_DATA);
   SetIndexBuffer(4,insideBuffer,INDICATOR_CALCULATIONS);
//initialize arrays
   ArrayInitialize(HighBuff,EMPTY_VALUE);
   ArrayInitialize(LowBuff,EMPTY_VALUE);
   ArrayInitialize(lineHighBuff,EMPTY_VALUE);
   ArrayInitialize(lineLowBuff,EMPTY_VALUE);
   ArrayInitialize(insideBuffer,EMPTY_VALUE);

   PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_ARROW);
   PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_ARROW);
   PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_LINE);
   PlotIndexSetInteger(3,PLOT_DRAW_TYPE,DRAW_LINE);

//--- indexes draw begin settings
//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,4);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,4);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,4);
   PlotIndexSetInteger(3,PLOT_DRAW_BEGIN,4);
//--- indexes shift settings
   PlotIndexSetInteger(0,PLOT_SHIFT,0);
   PlotIndexSetInteger(1,PLOT_SHIFT,0);
   PlotIndexSetInteger(2,PLOT_SHIFT,0);
   PlotIndexSetInteger(3,PLOT_SHIFT,0);


   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);

   if(_Period==PERIOD_M15){ timeframe=PERIOD_M15; timeframe_name="15-Minutes"; }
   if(_Period==PERIOD_H1) { timeframe = PERIOD_H1; timeframe_name = "Hourly"; }
   if(_Period==PERIOD_D1) { timeframe = PERIOD_D1; timeframe_name = "Daily"; }
   if(_Period==PERIOD_W1) { timeframe = PERIOD_W1; timeframe_name = "Weekly"; }
   if(_Period==PERIOD_M1) { timeframe = PERIOD_MN1; timeframe_name = "Monthly"; }
//--- indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,"InsideBar- "+timeframe_name);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   //if(rates_total-prev_calculated<=0)return(0);
   int counted_bars=prev_calculated;
   int limit = 1;

//---- check for possible errors
   if(counted_bars < 0) return(-1);

//---- last counted bar will be recounted
   if(counted_bars>0) counted_bars--;
   limit=rates_total-counted_bars;
   
   if(prev_calculated==0 || rates_total - counted_bars > 1)
     {
      limit=rates_total;
 
     }

//for(int i=1; i<limit; i++)
   for(int i=1; i<limit; i++)
     {

      HighBuff[i]=EMPTY_VALUE;
      LowBuff[i]=EMPTY_VALUE;
      lineHighBuff[i]= EMPTY_VALUE;
      lineLowBuff[i] = EMPTY_VALUE;
      insideBuffer[i] = EMPTY_VALUE;
      
      if(!isInsideDay)
        {
         if(high[i-1]>high[i] && low[i-1]<low[i])
           {
            HighBuff[i]= high[i];
            LowBuff[i] = low[i];

            upperDailyBound=high[i-1];
            lowerDailyBound=low[i-1];
            isInsideDay=true;
            insideBuffer[i] = 1;

            // if(i>1 && lineHighBuff[i-2]==EMPTY_VALUE && lineLowBuff[i-2]==EMPTY_VALUE)
            //   {
            //   lineHighBuff[i-2]=EMPTY_VALUE;
            //  lineLowBuff[i-2]=EMPTY_VALUE;
            //}

            lineHighBuff[i-1]=upperDailyBound;
            lineHighBuff[i]=upperDailyBound;

            lineLowBuff[i-1]=lowerDailyBound;
            lineLowBuff[i]=lowerDailyBound;

            //lineLowBuff[i+1]=EMPTY_VALUE;
            //lineHighBuff[i+1]=EMPTY_VALUE;

           }
         //clear next buffer value.
         //lineHighBuff[i+1]=EMPTY_VALUE;
         //lineLowBuff[i+1]=EMPTY_VALUE;
        }
      else //you are already an inside bar
        {
        
         if(high[i-1]>high[i] && low[i-1]<low[i])
           {
            HighBuff[i]= high[i];
            LowBuff[i] = low[i];

            //upperDailyBound=high[i-1];
            //lowerDailyBound=low[i-1];

            lineHighBuff[i]=upperDailyBound;
            lineLowBuff[i]=lowerDailyBound;
            insideBuffer[i] = 1;
           }
         else if(high[i]>=upperDailyBound && low[i]<=lowerDailyBound)
           {
            isInsideDay=false;
            //insideBuffer[i] = 0;
           }
         //breached low but closed outside
         else if(low[i]<lowerDailyBound && high[i]<upperDailyBound && close[i]<lowerDailyBound)
           {
            isInsideDay=false;
            //insideBuffer[i] = 0;
           }
         //breached high but closed outside
         else if(high[i]>upperDailyBound && low[i]>lowerDailyBound && close[i]>upperDailyBound)
           {
            isInsideDay=false;
            //insideBuffer[i] = 0;
           }
         //breached low but closed inside
         else if(low[i]<lowerDailyBound && high[i]<upperDailyBound && close[i]>lowerDailyBound && isInsideDay)
           {
            if(ObjectFind(0,buyName+IntegerToString(countBUY))<0)
              {
               if(!ObjectCreate(0,buyName+IntegerToString(countBUY),OBJ_ARROW_THUMB_UP,0,time[i],low[i]))
                 {
                  Print("Error: can't create object! code #",GetLastError());
                  return(0);
                 }
               ObjectSetInteger(0,buyName+IntegerToString(countBUY),OBJPROP_WIDTH,5);
               countBUY++;
              }
            lineHighBuff[i]=upperDailyBound;
            lineLowBuff[i]=lowerDailyBound;
            insideBuffer[i] = 2;
            isInsideDay=false;
           }
         //breached high but closed inside
         else if(high[i]>upperDailyBound && low[i]>lowerDailyBound && close[i]>lowerDailyBound && isInsideDay)
           {
            if(ObjectFind(0,sellName+IntegerToString(countSELL))<0)
              {
               if(!ObjectCreate(0,sellName+IntegerToString(countSELL),OBJ_ARROW_THUMB_DOWN,0,time[i],high[i]))
                 {
                  Print("Error: can't create objbect! code #",GetLastError());
                  return(0);
                 }
               ObjectSetInteger(0,sellName+IntegerToString(countSELL),OBJPROP_WIDTH,5);
               countSELL++;
              }
            lineHighBuff[i]=upperDailyBound;
            lineLowBuff[i]=lowerDailyBound;
            insideBuffer[i] = 3;
            isInsideDay=false;
           }
         else
           {
            lineHighBuff[i]=upperDailyBound;
            lineLowBuff[i]=lowerDailyBound;
            insideBuffer[i] = 4;
           }
        }
     }
   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
