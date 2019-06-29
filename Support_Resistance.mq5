//+------------------------------------------------------------------+
//|                                                    ATR Bands.mq5 |
//|                                              Copyright 2019, Ido |
//|                                              idos.elmo@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, Idos"
#property link      " http://www.mql5.com"
#property version   "1.00"

#property indicator_chart_window
#property indicator_buffers 13
#property indicator_plots 10

//1
#property indicator_label1  "High_1"
#property indicator_type1   DRAW_LINE
#property indicator_style1 STYLE_SOLID
#property indicator_width1 2
#property indicator_color1 clrBlue

#property indicator_label2  "High_2"
#property indicator_type2   DRAW_LINE
#property indicator_style2 STYLE_SOLID
#property indicator_width2 2
#property indicator_color2 clrBlue

#property indicator_label3  "High_3"
#property indicator_type3   DRAW_LINE
#property indicator_style3 STYLE_SOLID
#property indicator_width3 2
#property indicator_color3 clrCoral

#property indicator_label4  "High_4"
#property indicator_type4   DRAW_LINE
#property indicator_style4 STYLE_SOLID
#property indicator_width4 2
#property indicator_color4 clrChocolate

#property indicator_label5  "Low_1"
#property indicator_type5   DRAW_LINE
#property indicator_style5 STYLE_SOLID
#property indicator_width5 2
#property indicator_color5 clrChartreuse

#property indicator_label6  "Low_2"
#property indicator_type6   DRAW_LINE
#property indicator_style6 STYLE_SOLID
#property indicator_width6 2
#property indicator_color6 clrCadetBlue

#property indicator_label7  "Low_3"
#property indicator_type7   DRAW_LINE
#property indicator_style7 STYLE_SOLID
#property indicator_width7 2
#property indicator_color7 clrBurlyWood

#property indicator_label8  "Low_4"
#property indicator_type8   DRAW_LINE
#property indicator_style8 STYLE_SOLID
#property indicator_width8 2
#property indicator_color8 clrBrown

#property indicator_label9  "Resistance"
#property indicator_type9   DRAW_LINE
#property indicator_style9 STYLE_SOLID
#property indicator_width9 2
#property indicator_color9 clrGold

#property indicator_label10  "Support"
#property indicator_type10   DRAW_LINE
#property indicator_style10 STYLE_SOLID
#property indicator_width10 2
#property indicator_color10 clrNavy


input ENUM_TIMEFRAMES      inpTimeFrame=PERIOD_D1;   // Time frame for pivots
input int                  ATRperiod=12;
input double               percent=0.15;
///-----
/////////////////////////////////////////////////////////////////
ENUM_TIMEFRAMES            iTimeFrame;
double ATR[];
double upperBand[];
double lowerBand[];
double UpBand[];
double LowBand[];
double myATR[];
double myTR[];

double max1[];
double max2[];
double max3[];
double max4[];

double min1[];
double min2[];
double min3[];
double min4[];

int TRcount=0;
int RSHcount=1;
int RSLcount=1;
int numOfPeriods;
int ATRcount;
int calcBars;
int pp_save;
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
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,max1,INDICATOR_DATA);
   SetIndexBuffer(1,max2,INDICATOR_DATA);
   SetIndexBuffer(2,max3,INDICATOR_DATA);
   SetIndexBuffer(3,max4,INDICATOR_DATA);
   SetIndexBuffer(4,min1,INDICATOR_DATA);
   SetIndexBuffer(5,min2,INDICATOR_DATA);
   SetIndexBuffer(6,min3,INDICATOR_DATA);
   SetIndexBuffer(7,min4,INDICATOR_DATA);
   SetIndexBuffer(8,UpBand,INDICATOR_DATA);
   SetIndexBuffer(9,LowBand,INDICATOR_DATA);
   SetIndexBuffer(10,ATR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(11,myATR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(12,myTR,INDICATOR_CALCULATIONS);

   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);
//PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,2);
//Specify colors for each index
//PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,clrRed);   //Zeroth index -> Blue
//PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,clrGreen); //First index  -> Orange

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
   double Ask,Bid;
   ulong Spread;
   Ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   Bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   Spread=SymbolInfoInteger(Symbol(),SYMBOL_SPREAD);

   ArrayResize(upperBand,RSHcount);
   ArrayResize(lowerBand,RSLcount);
   double rates=rates_total;
   int limit=rates_total-prev_calculated;

//if this is the first time 
//find where does the last day ends
   if(prev_calculated==0)
     {
      firstOpen=open[0];
      maxHigh=high[0];
      maxLow=low[0];
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
               upperBand[0] = maxHigh;
               lowerBand[0] = maxLow;
               maxHigh=0;
               maxLow=10;
               //ArrayPrint(upperBand,_Digits,NULL,0,WHOLE_ARRAY,ARRAYPRINT_INDEX);
              }
            else
              {
               isPeriod=false;
               dailyClose=close[i-1];

               myTR[TRcount]=MathMax(maxHigh,dailyClose)-MathMin(maxLow,dailyClose);
               TRcount++;

               int Hindex = ArrayBsearch(upperBand,maxHigh);
               int Lindex = ArrayBsearch(lowerBand,maxLow);

               if(checkDeviation(upperBand[Hindex],maxHigh))
                 {
                  upperBand[Hindex]=(maxHigh+upperBand[Hindex])/2;
                 }
               else
                 {
                  RSHcount++;
                  ArrayResize(upperBand,RSHcount);
                  upperBand[RSHcount-1]=maxHigh;
                  ArraySort(upperBand);
                 }

               if(checkDeviation(lowerBand[Lindex],maxLow))
                 {
                  lowerBand[Lindex]=(maxLow+lowerBand[Lindex])/2;
                 }
               else
                 {
                  RSLcount++;
                  ArrayResize(lowerBand,RSLcount);
                  lowerBand[RSLcount-1]=maxLow;
                  ArraySort(lowerBand);
                 }

               maxHigh=0;
               maxLow=10;
               //ArrayPrint(upperBand,_Digits,NULL,0,WHOLE_ARRAY,ARRAYPRINT_INDEX);
              }
            if(TRcount==ATRperiod)
               ATRcount=i;

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
         ATR[j]=0.0;
         firstValue+=myTR[j];
        }
      firstValue/=ATRperiod;
      ATR[ATRcount]=firstValue; //atr indicator

      dailyClose=close[ATRcount-1];
      TRcount=ATRperiod;
      //ArrayPrint(upperBand,_Digits,NULL,0,WHOLE_ARRAY,ARRAYPRINT_INDEX);
      limit=ATRcount+1;// calculate exact period + 1
      rates= rates_total -1;
     }
   else limit=prev_calculated;        //prev_calculated = rates_total - 1 
                                      //

   for(int i=limit; i<rates && !IsStopped(); i++)
     {
      ATR[i]=ATR[i-1];
      ArraySort(upperBand);
      ArraySort(lowerBand);
      //if(time[i]==D'26.1.2015 00:00:00')
      //   Alert("");

      UpBand[i]=UpBand[i-1];
      LowBand[i]=LowBand[i-1];
      max1[i] = max1[i-1];
      max2[i] = max2[i-1];
      max3[i] = max3[i-1];
      max4[i] = max4[i-1];

      min1[i] = min1[i-1];
      min2[i] = min2[i-1];
      min3[i] = min3[i-1];
      min4[i] = min4[i-1];


      bool NewDay=(time[i]/inSeconds)!=(time[i-1]/inSeconds);
      if(NewDay)
        {
         //1 PERIOD has passed
         isPeriod=true;
        }
      if(isPeriod)
        {
         if(time[i]==D'20.7.2017 14:30:00')
            Alert("");

         for(int j=pp_save; j<ATRcount; j++)
           {
            max1[j] = EMPTY_VALUE;
            max2[j] = EMPTY_VALUE;
            max3[j] = EMPTY_VALUE;
            max4[j] = EMPTY_VALUE;

            UpBand[j] =EMPTY_VALUE;
            LowBand[j]=EMPTY_VALUE;

            min1[j] = EMPTY_VALUE;
            min2[j] = EMPTY_VALUE;
            min3[j] = EMPTY_VALUE;
            min4[j] = EMPTY_VALUE;
           }

         int Hindex=ArrayBsearch(upperBand,maxHigh);
         int Lindex=ArrayBsearch(lowerBand,maxLow);

         if(checkDeviation(upperBand[Hindex],maxHigh))
           {
            upperBand[Hindex]=(maxHigh+upperBand[Hindex])/2;
           }
         else
           {
            RSHcount++;
            ArrayResize(upperBand,RSHcount);
            upperBand[RSHcount-1]=maxHigh;
            ArraySort(upperBand);
           }

         if(checkDeviation(lowerBand[Lindex],maxLow))
           {
            lowerBand[Lindex]=(maxLow+lowerBand[Lindex])/2;
           }
         else
           {
            RSLcount++;
            ArrayResize(lowerBand,RSLcount);
            lowerBand[RSLcount-1]=maxLow;
            ArraySort(lowerBand);
           }

         int x=ArraySize(upperBand);
         int y=ArraySize(lowerBand);
         int upIndex=ArrayBsearch(upperBand,Ask);
         int downIndex=ArrayBsearch(lowerBand,Bid);

         UpBand[i]=upperBand[upIndex];
         LowBand[i]=lowerBand[downIndex];

         double firstUP;
         double secondUP;
         double thirdUP;
         double fourthUP;
         double firstDOWN;
         double secondDOWN;
         double thirdDOWN;
         double fourthDOWN;

         if(upIndex==0)
           {
            firstUP=upperBand[1];
            secondUP=upperBand[2];
            thirdUP=upperBand[3];
            fourthUP=upperBand[4];
           }
         else if(upIndex==1)
           {
            firstUP=upperBand[0];
            secondUP=upperBand[2];
            thirdUP=upperBand[3];
            fourthUP=upperBand[4];
           }
         else if(upIndex==(x-1))
           {
            firstUP=upperBand[x-2];
            secondUP=upperBand[x-3];
            thirdUP=upperBand[x-4];
            fourthUP=upperBand[x-5];
           }
         else if(upIndex==(x-2))
           {
            firstUP=upperBand[x-1];
            secondUP=upperBand[x-3];
            thirdUP=upperBand[x-4];
            fourthUP=upperBand[x-5];
           }
         else
           {
            firstUP=upperBand[upIndex-1];
            secondUP=upperBand[upIndex-2];
            thirdUP=upperBand[upIndex+1];
            fourthUP=upperBand[upIndex+2];
           }

         if(downIndex==0)
           {
            firstDOWN=lowerBand[1];
            secondDOWN=lowerBand[2];
            thirdDOWN=lowerBand[3];
            fourthDOWN=lowerBand[4];
           }
         else if(downIndex==1)
           {
            firstDOWN=lowerBand[0];
            secondDOWN=lowerBand[2];
            thirdDOWN=lowerBand[3];
            fourthDOWN=lowerBand[4];
           }
         else if(downIndex==(y-1))
           {
            firstDOWN=lowerBand[y-2];
            secondDOWN=lowerBand[y-3];
            thirdDOWN=lowerBand[y-4];
            fourthDOWN=lowerBand[y-5];
           }
         else if(downIndex==(y-2))
           {
            firstDOWN=lowerBand[y-1];
            secondDOWN=lowerBand[y-3];
            thirdDOWN=lowerBand[y-4];
            fourthDOWN=lowerBand[y-5];
           }
         else
           {
            firstDOWN=lowerBand[downIndex-1];
            secondDOWN=lowerBand[downIndex-2];
            thirdDOWN=lowerBand[downIndex+1];
            fourthDOWN=lowerBand[downIndex+2];
           }

         max1[i] = firstUP;
         max2[i] = secondUP;
         max3[i] = thirdUP;
         max4[i] = fourthUP;
         min1[i] = firstDOWN;
         min2[i] = secondDOWN;
         min3[i] = thirdDOWN;
         min4[i] = fourthDOWN;




         dailyOpen=open[i];
         isPeriod=false;
         dailyClose=close[i-1];
         //calculate the True Range
         myTR[TRcount]=MathMax(maxHigh,dailyClose)-MathMin(maxLow,dailyClose);
         TRcount++;
         ATR[i]=ATR[ATRcount]+(myTR[TRcount-1]-myTR[TRcount-ATRperiod])/ATRperiod;
         pp_save=ATRcount;
         ATRcount=i;
         maxHigh=0;
         maxLow=999;
        }
      else
        {
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
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int periodToSeconds(int period)
  {
   int i;
   static int _per[]={1,2,3,4,5,6,10,12,15,20,30,0x4001,0x4002,0x4003,0x4004,0x4006,0x4008,0x400c,0x4018,0x8001,0xc001};
   static int _min[]={60,120,180,240,300,360,600,720,800,1200,1800,3600,7200,10800,14400,21600,28800,43200,86400,604800,2.628e+6};

   if(period==PERIOD_CURRENT)
      period=Period();
   for(i=0;i<20;i++) if(period==_per[i]) break;
   return(_min[i]);
  }
//+------------------------------------------------------------------+
bool checkDeviation(double source,double destination)
  {
   bool ans=false;
   double deviation=source/destination;
   double percentage=MathAbs(deviation*100-100);

   if(percentage<=percent)
      ans=true;

   return ans;
  }
//+------------------------------------------------------------------+
