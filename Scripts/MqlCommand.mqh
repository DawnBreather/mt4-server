//+------------------------------------------------------------------+
//| Module: MqlCommand.mqh                                           |
//| This file is part of the mt4-server project:                     |
//|     https://github.com/dingmaotu/mt4-server                      |
//|                                                                  |
//| Copyright 2017 Li Ding <dingmaotu@hotmail.com>                   |
//|                                                                  |
//| Licensed under the Apache License, Version 2.0 (the "License");  |
//| you may not use this file except in compliance with the License. |
//| You may obtain a copy of the License at                          |
//|                                                                  |
//|     http://www.apache.org/licenses/LICENSE-2.0                   |
//|                                                                  |
//| Unless required by applicable law or agreed to in writing,       |
//| software distributed under the License is distributed on an      |
//| "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,     |
//| either express or implied.                                       |
//| See the License for the specific language governing permissions  |
//| and limitations under the License.                               |
//+------------------------------------------------------------------+
#property strict
#include <Mql/Trade/FxSymbol.mqh>
#include <Mql/Trade/OrderPool.mqh>
#include <Mql/Trade/Account.mqh>
#include <Mql/Trade/Order.mqh>
#include <Mql/Format/Resp.mqh>
#include <stdlib.mqh>
//+------------------------------------------------------------------+
//| Wraps a specific MQL command                                     |
//+------------------------------------------------------------------+
interface MqlCommand
  {
   RespValue        *call(const RespArray &command);
  };
//+------------------------------------------------------------------+
//| Get all orders in the Trade Pool                                 |
//| Syntax: ORDERS                                                   |
//| Results:                                                         |
//|   Success: Array of orders in string format                      |
//|   Success: Nil if no orders                                      |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class OrdersCommand: public MqlCommand
  {
private:
   TradingPool       m_pool;
public:
   RespValue        *call(const RespArray &command)
     {
      int total=m_pool.total();
      if(total==0) return RespNil::getInstance();
      RespArray *res=new RespArray(total);
      for(int i=0; i<total;i++)
        {
         if(m_pool.select(i))
           {
            Order o;
            res.set(i,new RespString(o.toString()));
           }
         else
           {
            res.set(i,RespNil::getInstance());
           }
        }
      return res;
     }
  };
//+------------------------------------------------------------------+
//| Buy at market price                                              |
//| Syntax: BUY Symbol Lots                                          |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class BuyCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      if(command.size()!=3) return new RespError("Invalid number of arguments for command BUY!");
      string symbol=dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      double lots=StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
      int id=OrderSend(symbol,OP_BUY,lots,FxSymbol::getAsk(symbol),3,0,0,NULL,0,0,clrNONE);
      if(id==-1)
        {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to buy at market with error id (%d): %s",
                              ec,Mql::getErrorMessage(ec)));
        }
      else
        {
         return new RespInteger(id);
        }
     }
  };
//+------------------------------------------------------------------+
//| Sell at market price                                             |
//| Syntax: SELL Symbol Lots                                         |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class SellCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      if(command.size()!=3) return new RespError("Invalid number of arguments for command SELL!");
      string symbol=dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      double lots=StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
      int id=OrderSend(symbol,OP_SELL,lots,FxSymbol::getBid(symbol),3,0,0,NULL,0,0,clrNONE);
      if(id==-1)
        {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to sell at market with error id (%d): %s",
                              ec,Mql::getErrorMessage(ec)));
        }
      else
        {
         return new RespInteger(id);
        }
     }
  };
//+------------------------------------------------------------------+
//| Close a market order                                             |
//| Syntax: CLOSE Ticket Lots                                        |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class CloseCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      if(command.size()!=3 && command.size()!=2) return new RespError("Invalid number of arguments for command CLOSE!");
      int ticket=(int)StringToInteger(dynamic_cast<RespBytes*>(command[1]).getValueAsString());
      if(!Order::Select(ticket))
        {
         return new RespError("Order does not exist!");
        }
      string symbol=Order::Symbol();
      int op=Order::Type();
      double lots=0;
      if(command.size()==2)
        {
         lots=Order::Lots();
        }
      else
        {
         lots=StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
        }
      if(!OrderClose(ticket,lots,FxSymbol::priceForClose(symbol,op),3,clrNONE))
        {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to close market order #%d with error id (%d): %s",
                              ticket,ec,Mql::getErrorMessage(ec)));
        }
      else
        {
         return new RespString("Ok");
        }
     }
  };

//+------------------------------------------------------------------+
//| Place a sell limit order with SL and TP                          |
//| Syntax: SELLLIMIT Symbol Lots Price SL TP                        |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class SellLimitCommand: public MqlCommand
{
public:
   RespValue *call(const RespArray &command)
   {
      if(command.size() != 6) return new RespError("Invalid number of arguments for command SELLLIMIT!");

      string symbol = dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      double lots = StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
      double price = StringToDouble(dynamic_cast<RespBytes*>(command[3]).getValueAsString());
      double sl = StringToDouble(dynamic_cast<RespBytes*>(command[4]).getValueAsString());
      double tp = StringToDouble(dynamic_cast<RespBytes*>(command[5]).getValueAsString());

      int id = OrderSend(symbol, OP_SELLLIMIT, lots, price, 0, sl, tp, NULL, 0, 0, clrNONE);
      if(id == -1)
      {
         int ec = Mql::getLastError();
         return new RespError(StringFormat("Failed to place sell limit order with error id (%d): %s",
                              ec, Mql::getErrorMessage(ec)));
      }
      else
      {
         return new RespInteger(id);
      }
   }
};


//+------------------------------------------------------------------+
//| Place a buy limit order with SL and TP                           |
//| Syntax: BUYLIMIT Symbol Lots Price SL TP                         |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class BuyLimitCommand: public MqlCommand
{
public:
   RespValue *call(const RespArray &command)
   {
      if(command.size() != 6) return new RespError("Invalid number of arguments for command BUYLIMIT!");

      string symbol = dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      double lots = StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
      double price = StringToDouble(dynamic_cast<RespBytes*>(command[3]).getValueAsString());
      double sl = StringToDouble(dynamic_cast<RespBytes*>(command[4]).getValueAsString());
      double tp = StringToDouble(dynamic_cast<RespBytes*>(command[5]).getValueAsString());

      int id = OrderSend(symbol, OP_BUYLIMIT, lots, price, 0, sl, tp, NULL, 0, 0, clrNONE);
      if(id == -1)
      {
         int ec = Mql::getLastError();
         return new RespError(StringFormat("Failed to place buy limit order with error id (%d): %s",
                              ec, Mql::getErrorMessage(ec)));
      }
      else
      {
         return new RespInteger(id);
      }
   }
};

//+------------------------------------------------------------------+
//| Edit an existing order's SL and TP                               |
//| Syntax: EDIT Ticket SL TP                                        |
//| Results:                                                         |
//|   Success: "Ok" (RespString)                                     |
//|   Fail: RespError                                                |
//+------------------------------------------------------------------+
class EditCommand: public MqlCommand
{
public:
   RespValue *call(const RespArray &command)
   {
      if(command.size() != 4) return new RespError("Invalid number of arguments for command EDIT!");

      int ticket = (int)StringToInteger(dynamic_cast<RespBytes*>(command[1]).getValueAsString());
      double sl = StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
      double tp = StringToDouble(dynamic_cast<RespBytes*>(command[3]).getValueAsString());

      // First, select the order by ticket
      if(!OrderSelect(ticket, SELECT_BY_TICKET))
      {
         int ec = GetLastError();
         return new RespError(StringFormat("Failed to select order #%d with error id (%d): %s",
                                           ticket, ec, ErrorDescription(ec)));
      }

      // Modify the order with new SL and TP
      if(!OrderModify(ticket, OrderOpenPrice(), sl, tp, 0, clrNONE))
      {
         int ec = GetLastError();
         return new RespError(StringFormat("Failed to modify order #%d with error id (%d): %s",
                                           ticket, ec, ErrorDescription(ec)));
      }

      return new RespString("Ok");
   }
};

//+------------------------------------------------------------------+
//| Get the account's free margin                                    |
//| Syntax: FREEMARGIN                                               |
//| Results:                                                         |
//|   Success: Free margin amount (RespDouble)                       |
//|   Fail: RespError                                                |
//+------------------------------------------------------------------+
class FreeMarginCommand: public MqlCommand
{
public:
   RespValue *call(const RespArray &command)
   {
      // Ensure no additional arguments are passed
      if(command.size() != 1) return new RespError("Invalid number of arguments for command FREEMARGIN!");

      double freeMargin = AccountFreeMargin();
      return new RespString(IntegerToString(MathRound(freeMargin), 0, ""));
   }
};



//+------------------------------------------------------------------+
//| Quit server connection                                           |
//| Syntax: QUIT                                                     |
//| Results:                                                         |
//|   The server will close the connection                           |
//+------------------------------------------------------------------+
class QuitCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      return NULL;
     }
  };
//+------------------------------------------------------------------+
