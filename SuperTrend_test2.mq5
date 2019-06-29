//+------------------------------------------------------------------+
//|                                                   SuperTrend.mq5 |
//|                                              Copyright 2019, Ido |
//|                                              idos.elmo@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, Idos"
#property link      " http://www.mql5.com"
#property version   "1.00"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots 1

#property indicator_label1  "SuperTrend"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_style1 STYLE_SOLID
#property indicator_width1 2
#property indicator_color1  clrRed,clrGreen 


input ENUM_TIMEFRAMES      inpTimeFrame=PERIOD_D1;   // Time frame for pivots
input double               SuperTrend_Multiplier=3;
input int                  ATRperiod=3;
///-----
/////////////////////////////////////////////////////////////////
ENUM_TIMEFRAMES            iTimeFrame;
double ATR[];
double UpTrend[];
double DownTrend[];
double Up[];
double Down[];
double SuperTrend[];
double trend[];
double ColorBuffer[];
double myATR[];
double myTR[];
int TRcount=0;
int numOfPeriods;
int ATRcount;
int calcBars;
double firstOpen;
double dailyClose;
double dailyOpen;
double dailyHigh;
double dailyLow;
bool isPeriod=false;
bool isFirstTime=false;
double maxHigh;
double maxLow;
int inSeconds;
bool STnewday=false;
int changeOfTrend;
int flag;
int flagh;
int STindex;
double up_st_calc;
double down_st_calc;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,SuperTrend,INDICATOR_DATA);
   SetIndexBuffer(1,ColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,ATR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,UpTrend,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,DownTrend,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,Up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,Down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,myATR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,myTR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,trend,INDICATOR_CALCULATIONS);

   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);

   PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,2);
//-----Specify colors for each index
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,clrRed);   //Zeroth index -> Blue
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,clrGreen); //First index  -> Orange

   iTimeFrame=(inpTimeFrame>=Period()) ? inpTimeFrame : Period();

   int minutesPeriod = periodToMinutes(Period());
   int minutesChosen = periodToMinutes(iTimeFrame);

   calcBars=minutesChosen/minutesPeriod;
   inSeconds=periodToSeconds(iTimeFrame);

//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
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

   ArrayResize(trend,rates_total);
   double rates=rates_total;
   int limit=rates_total-prev_calculated;

   if(prev_calculated==0)
     {
      firstOpen=open[0];
      maxHigh=high[0];
      maxLow=low[0];
      double mod=MathMod(rates,calcBars);
      if(mod!=0)
        {
         for(int i=0; i<mod; i++)
           {
            rates--;
            if(MathMod(rates,calcBars)==0)
              {
               numOfPeriods=(int)(rates/calcBars);
               limit=(int)rates+2;
               break;
              }
           }
        }
      else if(mod==0)
        {
         limit=rates_total;
         numOfPeriods=(int)(rates_total/calcBars);
        }

      //run for number of periods in our chart

      for(int i=1; i<limit; i++)
        {

         bool NewDay=(time[i]/inSeconds)!=(time[i-1]/inSeconds);
         if(NewDay) //MathMod(i,calcBars)==0 || 
           {
            //1 PERIOD has passed
            isPeriod=true;
            if(i<=calcBars) isFirstTime=true;
           }
         if(isPeriod)
           {
            //--- filling out the array of True Range values for each period
            if(isFirstTime)
              {
               dailyClose=close[i-1];
               isPeriod=false;
               isFirstTime=false;
               maxHigh=0;
               maxLow=10;
              }
            else
              {
               isPeriod=false;
               dailyClose=close[i-1];
               myTR[TRcount]=MathMax(maxHigh,dailyClose)-MathMin(maxLow,dailyClose);
               TRcount++;
               maxHigh=0;
               maxLow=10;
              }
            if(TRcount==ATRperiod-1)
              {
               STindex=i;
              }
            if(TRcount==ATRperiod)
              {
               ATRcount=i;
              }
           }
         else
           {
            double tempHigh=MathMax(high[i-1],high[i]);
            maxHigh=MathMax(tempHigh,maxHigh);
            double tempLow=MathMin(low[i-1],low[i]);
            maxLow=MathMin(tempLow,maxLow);
           }

        }

      //prev calc is still 0
      double firstValue=0;
      for(int j=0; j<ATRperiod; j++)
        {
         myATR[j]=0.0;
         SuperTrend[j]=0.0;
         firstValue+=myTR[j];
        }
      firstValue/=ATRperiod;
      ATR[ATRcount]=firstValue; //atr indicator
      dailyClose=close[ATRcount-1];
      TRcount=ATRperiod;

      limit=calcBars*(ATRperiod+1)+1;// calculate exact period + 1
      rates= rates_total -1;
     }
   else limit=prev_calculated;        //prev_calculated = rates_total - 1 
                                      //

   for(int i=limit; i<rates && !IsStopped(); i++)
     {
      ATR[i]=ATR[i-1];

      //if(time[i]==D'1.7.2013 00:00:00')
      //   Alert("");

      bool NewDay=(time[i]/inSeconds)!=(time[i-1]/inSeconds);
      if(NewDay) //MathMod(i,calcBars)==0 || 
        {
         //1 PERIOD has passed
         isPeriod=true;
        }
      if(isPeriod)
        {
         STnewday=true;
         dailyOpen=open[i];
         isPeriod=false;

         //calculate the True Range
         dailyClose=close[i-1];
         myTR[TRcount]=MathMax(maxHigh,dailyClose)-MathMin(maxLow,dailyClose);
         TRcount++;
         ATR[i]=ATR[ATRcount]+(myTR[TRcount-1]-myTR[TRcount-ATRperiod])/ATRperiod;

         double middle=(maxHigh+maxLow)/2;
         up_st_calc=middle+SuperTrend_Multiplier*ATR[i];
         down_st_calc=middle-SuperTrend_Multiplier*ATR[i];

         Up[i]=up_st_calc;
         Down[i]=down_st_calc;

         if(dailyClose>=Up[ATRcount])
           {
            trend[i]=1;
            if(trend[ATRcount]==-1) changeOfTrend=1;
           }
         else if(dailyClose<=Down[ATRcount])
           {
            trend[i]=-1;
            if(trend[ATRcount]==1) changeOfTrend=1;
           }
         else if(trend[ATRcount]==1)
           {
            trend[i]=1;
            changeOfTrend=0;
           }
         else if(trend[ATRcount]==-1)
           {
            trend[i]=-1;
            changeOfTrend=0;
           }
         if(trend[i]<0 && trend[ATRcount]>0)
           {
            flag=1;
           }
         else
           {
            flag=0;
           }
         if(trend[i]>0 && trend[ATRcount]<0)
           {
            flagh=1;
           }
         else
           {
            flagh=0;
           }
         if(trend[i]>0 && Down[i]<Down[ATRcount])
           {
            Down[i]=Down[ATRcount];
           }
         if(trend[i]<0 && Up[i]>Up[ATRcount])
           {
            Up[i]=Up[ATRcount];
           }
         if(flag==1)
           {
            Up[i]=up_st_calc;
           }
         if(flagh==1)
           {
            Down[i]=down_st_calc;
           }

         //-- Draw the indicator
         if(trend[i]==1)
           {
            SuperTrend[i]=Down[i];
            if(changeOfTrend==1)
              {
               SuperTrend[ATRcount]=SuperTrend[STindex];
               changeOfTrend=0;
              }
            ColorBuffer[i]=1;
           }
         else if(trend[i]==-1)
           {
            SuperTrend[i]=Up[i];
            if(changeOfTrend==1)
              {
               SuperTrend[ATRcount]=SuperTrend[STindex];
               changeOfTrend=0;
              }
            ColorBuffer[i]=0;
           }


         STindex=ATRcount;
         ATRcount=i;
         maxHigh=-999;
         maxLow=999;
        }
      else
        {

         Up[i]=Up[i-1];
         Down[i]=Down[i-1];
         SuperTrend[i]=SuperTrend[i-1];
         ColorBuffer[i]=ColorBuffer[i-1];
         if(close[i]>=Up[ATRcount])
           {
            trend[i]=1;
            if(trend[ATRcount]==-1) changeOfTrend=1;
           }
         else if(close[i]<=Down[ATRcount])
           {
            trend[i]=-1;
            if(trend[ATRcount]==1) changeOfTrend=1;
           }         else if(trend[ATRcount]==1)
           {
            trend[i]=1;
            changeOfTrend=0;
           }
         else if(trend[ATRcount]==-1)
           {
            trend[i]=-1;
            changeOfTrend=0;
           }
         if(trend[i]<0 && trend[ATRcount]>0)
           {
            flag=1;
           }
         else
           {
            flag=0;
           }
         if(trend[i]>0 && trend[ATRcount]<0)
           {
            flagh=1;
           }
         else
           {
            flagh=0;
           }
         if(trend[i]>0 && Down[i]<Down[ATRcount])
           {
            Down[i]=Down[ATRcount];
           }
         if(trend[i]<0 && Up[i]>Up[ATRcount])
           {
            Up[i]=Up[ATRcount];
           }
         if(flag==1)
           {
            Up[i]=up_st_calc;
           }
         if(flagh==1)
           {
            Down[i]=down_st_calc;
           }

         if(STnewday)
           {
            STnewday=false;
            //SuperTrend[i]=EMPTY_VALUE;
           }
         double tempHigh=MathMax(high[i-1],high[i]);
         maxHigh=MathMax(tempHigh,maxHigh);
         double tempLow=MathMin(low[i-1],low[i]);
         maxLow=MathMin(tempLow,maxLow);
        }

     }

//--- return value of prev_calculated for next call
   ChartRedraw();

   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int periodToMinutes(int period)
  {
   int i;
   static int _per[]={1,2,3,4,5,6,10,12,15,20,30,0x4001,0x4002,0x4003,0x4004,0x4006,0x4008,0x400c,0x4018,0x8001,0xc001};
   static int _min[]={1,2,3,4,5,6,10,12,15,20,30,60,120,180,240,360,480,720,1440,10080,43200};

   if(period==PERIOD_CURRENT)
      period=Period();
   for(i=0;i<20;i++) if(period==_per[i]) break;
   return(_min[i]);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int dateArrayBsearch(MqlRates &rates[],datetime toFind,int total)
  {
   int mid   = 0;
   int first = 0;
   int last  = total-1;

   while(last>=first)
     {
      mid=(first+last)>>1;
      if(toFind==rates[mid].time || (mid>0 && (toFind>rates[mid].time) && (toFind<rates[mid-1].time))) break;
      if(toFind>rates[mid].time)
         last=mid-1;
      else  first=mid+1;
     }
   return (mid);
  }
//+------------------------------------------------------------------+
int periodToSeconds(int period)
  {
   int i;
   static int _per[]={1,2,3,4,5,6,10,12,15,20,30,0x4001,0x4002,0x4003,0x4004,0x4006,0x4008,0x400c,0x4018,0x8001};
   static int _min[]={60,120,180,240,300,360,600,720,800,1200,1800,3600,7200,10800,14400,21600,28800,43200,86400,604800};

   if(period==PERIOD_CURRENT)
      period=Period();
   for(i=0;i<20;i++) if(period==_per[i]) break;
   return(_min[i]);
  }
//+------------------------------------------------------------------+
