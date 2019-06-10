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
string buyName="BuyArrow";
string sellName="SellArrow";
int countBUY=0;
int countSELL=0;
bool isInsideDay=false;
double upperDailyBound;
double lowerDailyBound;

//---- buffers ----//
double HighBuff[];
double LowBuff[];
double lineHighBuff[];
double lineLowBuff[];
double insideBuffer[];
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

//set indicators type
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

//--- indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,"InsideBar");

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

   int counted_bars=prev_calculated;
   int limit=1;

//---- check for possible errors
   if(counted_bars < 0) return(-1);

//---- last counted bar will be recounted
   if(counted_bars>0) counted_bars--;
   limit=rates_total-counted_bars;

   if(prev_calculated==0 || rates_total-counted_bars>1)
     {
      limit=rates_total;
     }

   for(int i=1; i<limit; i++)
     {
      HighBuff[i]=EMPTY_VALUE;
      LowBuff[i]=EMPTY_VALUE;
      lineHighBuff[i]= EMPTY_VALUE;
      lineLowBuff[i] = EMPTY_VALUE;
      insideBuffer[i]= EMPTY_VALUE;

      if(!isInsideDay)
        {
         if(high[i-1]>high[i] && low[i-1]<low[i])
           {
            HighBuff[i]= high[i];
            LowBuff[i] = low[i];

            upperDailyBound=high[i-1];
            lowerDailyBound=low[i-1];
            isInsideDay=true;
            insideBuffer[i]=1;
            if(insideBuffer[i-1]==2 || insideBuffer[i-1]==3) //inside right after a breach
              {
               insideBuffer[i]=0;
              }

            lineHighBuff[i-1]=upperDailyBound;
            lineHighBuff[i]=upperDailyBound;

            lineLowBuff[i-1]=lowerDailyBound;
            lineLowBuff[i]=lowerDailyBound;

           }
        }
      else //you are already an inside bar
        {

         if(high[i-1]>high[i] && low[i-1]<low[i])
           {
            HighBuff[i]= high[i];
            LowBuff[i] = low[i];

            lineHighBuff[i]=upperDailyBound;
            lineLowBuff[i]=lowerDailyBound;
            insideBuffer[i]=4;
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
               if(!ObjectCreate(0,buyName+IntegerToString(countBUY),OBJ_ARROW_THUMB_UP,0,time[i],low[i]-0.0004))
                 {
                  Print("Error: can't create object! code #",GetLastError());
                  return(0);
                 }
               ObjectSetInteger(0,buyName+IntegerToString(countBUY),OBJPROP_WIDTH,5);
               countBUY++;
              }
            lineHighBuff[i]=upperDailyBound;
            lineLowBuff[i]=lowerDailyBound;
            insideBuffer[i]=2;
            isInsideDay=false;
           }
         //breached high but closed inside
         else if(high[i]>upperDailyBound && low[i]>lowerDailyBound && close[i]>lowerDailyBound && isInsideDay)
           {
            if(ObjectFind(0,sellName+IntegerToString(countSELL))<0)
              {
               if(!ObjectCreate(0,sellName+IntegerToString(countSELL),OBJ_ARROW_THUMB_DOWN,0,time[i],high[i]+0.0015))
                 {
                  Print("Error: can't create objbect! code #",GetLastError());
                  return(0);
                 }
               ObjectSetInteger(0,sellName+IntegerToString(countSELL),OBJPROP_WIDTH,5);
               countSELL++;
              }
            lineHighBuff[i]=upperDailyBound;
            lineLowBuff[i]=lowerDailyBound;
            insideBuffer[i]=3;
            isInsideDay=false;
           }
         else //nothing changed
           {
            lineHighBuff[i]=upperDailyBound;
            lineLowBuff[i]=lowerDailyBound;
            insideBuffer[i]=4;
           }
        }
     }

   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
