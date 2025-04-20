import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { Slider } from "./ui/slider";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Switch } from "./ui/switch";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "./ui/tooltip";
import { cn } from "@/lib/utils";

interface BudgetItem {
  name: string;
  value: number;
  min: number;
  max: number;
  initialMax: number;
  step: number;
  percentage?: number;
}

const BUDGET_PERCENTAGES = {
  'Venue Rental': 25,
  'Catering': 30,
  'Equipment': 5,
  'Staffing': 5,
  'Marketing': 10,
  'Miscellaneous': 5,
  // 20% left as profit buffer
};

// Add this style block at the top of your component
const inputStyles = `
  [type='number']::-webkit-inner-spin-button,
  [type='number']::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  [type='number'] {
    -moz-appearance: textfield;
  }
`;

// Add this helper function at the top level, before the EventCalculator component
const roundToNearest5 = (num: number) => Math.ceil(num / 5) * 5;

const EXPENSE_COLORS = {
  'Venue Rental': '#FF6B6B',
  'Catering': '#4ECDC4',
  'Equipment': '#45B7D1',
  'Staffing': '#96CEB4',
  'Marketing': '#FFEEAD',
  'Miscellaneous': '#D4A5A5'
};

// Add these constants at the top level
const BASE_TICKET_PRICE = 50;

const CORE_EXPENSE_RULES = {
  'Venue Rental': {
    baseRate: 15, // Reduced from 50
    minValue: 500,
    maxValue: 10000,
    scaleThreshold: 100, // Point at which scaling rate reduces
    scaleRate: 0.7 // Rate multiplier for tickets above threshold
  },
  'Catering': {
    baseRate: 12, // Reduced from 35
    minValue: 300,
    maxValue: 15000,
    scaleThreshold: 100,
    scaleRate: 0.6
  },
  'Equipment': {
    baseRate: 5, // Reduced from 10
    minValue: 200,
    maxValue: 5000,
    scaleThreshold: 100,
    scaleRate: 0.5
  },
  'Staffing': {
    baseRate: 8, // Reduced from 20
    minValue: 300,
    maxValue: 8000,
    scaleThreshold: 100,
    scaleRate: 0.8
  }
};

const MARKETING_RULES = {
  ticketPriceScale: 0.02, // Only 2% of price difference affects marketing
  sponsorshipContribution: 0.02, // 2% of sponsorships
  donationContribution: 0, // Donations no longer affect marketing
  merchandiseContribution: 0.01, // 1% of merchandise
  baseValue: 300,
  minValue: 200,
  maxValue: 10000
};

const MISC_RULES = {
  sponsorshipContribution: 0.02, // 2% of sponsorships
  donationContribution: 0, // Donations no longer affect miscellaneous
  merchandiseContribution: 0.01, // 1% of merchandise
  baseValue: 150,
  minValue: 100,
  maxValue: 5000
};

// Replace the old constants with new cost model rules
const VENUE_TIERS = [
  { maxTickets: 150, cost: 2000 },
  { maxTickets: 300, cost: 3500 },
  { maxTickets: 500, cost: 6000 },
  { maxTickets: 1000, cost: 10000 },
  { maxTickets: Infinity, cost: 15000 }
];

const COST_RULES = {
  catering: {
    baseCost: 2000,
    maxCost: 8000,
    scaleRate: 0.02 // 2% increase per 10 tickets
  },
  staffing: {
    baseCost: 1500,
    maxCost: 6000,
    scaleRate: 0.015 // 1.5% increase per 10 tickets
  },
  equipment: {
    baseCost: 1000,
    maxCost: 5000,
    scaleRate: 0.01 // 1% increase per 10 tickets
  },
  marketing: {
    baseCost: 1000,
    perTicketAmount: 2, // Fixed $2 per ticket instead of percentage
    maxCost: 10000
  },
  miscellaneous: {
    percentageOfOtherExpenses: 0.05 // 5% of other expenses
  }
};

type EventSize = 'SMALL' | 'MEDIUM' | 'LARGE' | 'XLARGE' | 'HUGE';

type ExpenseCategory = 'Venue Rental' | 'Catering' | 'Equipment' | 'Staffing' | 'Marketing' | 'Miscellaneous';

interface EventSizeConfig {
  maxTickets: number;
  name: string;
}

interface CostConfig {
  SMALL: number;
  MEDIUM: number;
  LARGE: number;
  XLARGE: number;
  HUGE: number;
}

// Define event size categories
const EVENT_SIZES: Record<EventSize, EventSizeConfig> = {
  SMALL: { maxTickets: 100, name: 'Small Event' },
  MEDIUM: { maxTickets: 250, name: 'Medium Event' },
  LARGE: { maxTickets: 500, name: 'Large Event' },
  XLARGE: { maxTickets: 1000, name: 'Extra Large Event' },
  HUGE: { maxTickets: Infinity, name: 'Huge Event' }
};

// Fixed costs for each expense category based on event size
const FIXED_COSTS: Record<ExpenseCategory, CostConfig> = {
  'Venue Rental': {
    SMALL: 2000,
    MEDIUM: 3500,
    LARGE: 6000,
    XLARGE: 10000,
    HUGE: 15000
  },
  'Catering': {
    SMALL: 1500,
    MEDIUM: 3000,
    LARGE: 5000,
    XLARGE: 8000,
    HUGE: 12000
  },
  'Equipment': {
    SMALL: 1000,
    MEDIUM: 2000,
    LARGE: 3500,
    XLARGE: 5000,
    HUGE: 7500
  },
  'Staffing': {
    SMALL: 1200,
    MEDIUM: 2400,
    LARGE: 4000,
    XLARGE: 6000,
    HUGE: 9000
  },
  'Marketing': {
    SMALL: 1000,
    MEDIUM: 2000,
    LARGE: 3500,
    XLARGE: 5000,
    HUGE: 7500
  },
  'Miscellaneous': {
    SMALL: 500,
    MEDIUM: 1000,
    LARGE: 2000,
    XLARGE: 3000,
    HUGE: 4500
  }
};

// Base costs for expenses
const BASE_COSTS = {
  'Venue Rental': 2000,
  'Catering': 1500,
  'Equipment': 1000,
  'Staffing': 1200,
  'Marketing': 1000,
  'Miscellaneous': 500
};

// Scale factors for expenses that grow with ticket quantity
const SCALE_FACTORS = {
  'Venue Rental': 0.4,  // Grows moderately with attendance
  'Catering': 0.5,     // Grows fastest with attendance
  'Marketing': 0.25,   // Grows slower with attendance
  'Miscellaneous': 0.2 // Grows slowest with attendance
};

const EventCalculator: React.FC = () => {
  const [isAutoBudget, setIsAutoBudget] = useState(false);
  const [manualExpenses, setManualExpenses] = useState<BudgetItem[]>([]);
  const [ticketDetails, setTicketDetails] = useState({
    quantity: 50,
    price: 10
  });

  const [expenses, setExpenses] = useState<BudgetItem[]>([
    { name: 'Venue Rental', value: 0, min: 0, max: 10000, initialMax: 10000, step: 10, percentage: 25 },
    { name: 'Catering', value: 0, min: 0, max: 15000, initialMax: 15000, step: 10, percentage: 30 },
    { name: 'Equipment', value: 0, min: 0, max: 3000, initialMax: 3000, step: 10, percentage: 10 },
    { name: 'Staffing', value: 0, min: 0, max: 4000, initialMax: 4000, step: 10, percentage: 10 },
    { name: 'Marketing', value: 0, min: 0, max: 6000, initialMax: 6000, step: 10, percentage: 10 },
    { name: 'Miscellaneous', value: 0, min: 0, max: 2000, initialMax: 2000, step: 10, percentage: 5 },
  ]);

  const [incomes, setIncomes] = useState<BudgetItem[]>([
    { name: 'Ticket Sales', value: 0, min: 0, max: 50000, initialMax: 50000, step: 10 },
    { name: 'Sponsorships', value: 0, min: 0, max: 5000, initialMax: 5000, step: 10 },
    { name: 'Merchandise', value: 0, min: 0, max: 3000, initialMax: 3000, step: 10 },
    { name: 'Donations', value: 0, min: 0, max: 2000, initialMax: 2000, step: 10 },
  ]);

  const [lastClickTime, setLastClickTime] = useState<number>(0);
  const DOUBLE_CLICK_DELAY = 300; // milliseconds

  const handleMouseDown = (callback: () => void) => (e: React.MouseEvent) => {
    const currentTime = new Date().getTime();
    const timeDiff = currentTime - lastClickTime;
    
    if (timeDiff < DOUBLE_CLICK_DELAY) {
      e.preventDefault();
      callback();
    }
    
    setLastClickTime(currentTime);
  };

  // Update the auto-budget effect
  useEffect(() => {
    if (isAutoBudget && !manualExpenses.length) {
      const newExpenses = expenses.map(expense => {
        const baseCost = BASE_COSTS[expense.name as keyof typeof BASE_COSTS];
        
        if (['Venue Rental', 'Catering', 'Marketing', 'Miscellaneous'].includes(expense.name)) {
          const scaleFactor = SCALE_FACTORS[expense.name as keyof typeof SCALE_FACTORS];
          let value = Math.round(
            baseCost * Math.pow(1 + (ticketDetails.quantity / 100), scaleFactor)
          );
          
          // Add marketing adjustment for ticket price
          if (expense.name === 'Marketing') {
            const priceDifference = Math.max(0, ticketDetails.price - BASE_TICKET_PRICE);
            const priceAdjustment = Math.round(priceDifference * ticketDetails.quantity * 0.02);
            value += priceAdjustment;
          }
          
          return {
            ...expense,
            value: Math.min(expense.max, value)
          };
        } else {
          // Equipment and Staffing remain at base cost
          return {
            ...expense,
            value: baseCost
          };
        }
      });
      
      setExpenses(newExpenses);
    }
  }, [isAutoBudget, ticketDetails.quantity, ticketDetails.price, manualExpenses.length, expenses]);

  // Update ticket sales effect
  useEffect(() => {
    const totalTicketSales = ticketDetails.quantity * ticketDetails.price;
    const newIncomes = [...incomes];
    const ticketSalesIndex = newIncomes.findIndex(income => income.name === 'Ticket Sales');
    if (ticketSalesIndex !== -1) {
      newIncomes[ticketSalesIndex].value = totalTicketSales;
      setIncomes(newIncomes);
    }
  }, [ticketDetails, incomes]);

  const roundToNearestStep = (value: number, step: number) => {
    // Special handling for step size of 5
    if (step === 5) {
      const remainder = value % 5;
      // If remainder is less than 2.5, round down to nearest 5
      // If remainder is 2.5 or greater, round up to nearest 5
      return remainder < 2.5 ? value - remainder : value + (5 - remainder);
    }
    // For other step sizes, round to nearest step
    return Math.round(value / step) * step;
  };

  const handleExpenseChange = (index: number, value: number) => {
    const newExpenses = [...expenses];
    const expense = newExpenses[index];
    expense.value = Math.min(Math.max(value, expense.min), expense.max);
    setExpenses(newExpenses);
    
    // Store manual adjustments when in auto-budget mode
    if (isAutoBudget) {
      setManualExpenses(newExpenses);
    }
  };

  const handleExpenseDoubleClick = (index: number) => {
    const expense = expenses[index];
    const currentValue = expense.value;
    const step = expense.step;
    
    // Calculate both round up and round down values
    const roundDownValue = Math.floor(currentValue / step) * step;
    const roundUpValue = Math.ceil(currentValue / step) * step;
    
    // Choose the closer value
    const newValue = (currentValue - roundDownValue) <= (roundUpValue - currentValue) 
      ? roundDownValue 
      : roundUpValue;
    
    handleExpenseChange(index, newValue);
  };

  const handleIncomeChange = (index: number, value: number) => {
    if (incomes[index].name !== 'Ticket Sales') {
      const newIncomes = [...incomes];
      newIncomes[index].value = Math.min(Math.max(value, newIncomes[index].min), newIncomes[index].max);
      setIncomes(newIncomes);
    }
  };

  const handleIncomeDoubleClick = (index: number) => {
    if (incomes[index].name !== 'Ticket Sales') {
      const income = incomes[index];
      const roundedValue = roundToNearestStep(income.value, income.step);
      handleIncomeChange(index, roundedValue);
    }
  };

  const handleTicketDetailDoubleClick = (field: 'quantity' | 'price') => {
    const value = ticketDetails[field];
    const step = 1;
    const roundedValue = roundToNearestStep(value, step);
    setTicketDetails(prev => ({ ...prev, [field]: roundedValue }));
  };

  const calculatePercentage = (value: number, total: number) => {
    return total > 0 ? Math.round((value / total) * 100) : 0;
  };

  // Calculate total values and percentages
  const totalExpenses = expenses.reduce((sum, item) => sum + item.value, 0);
  const totalIncome = incomes.reduce((sum, item) => sum + item.value, 0);
  const profit = totalIncome - totalExpenses;
  
  // Calculate progress bar percentages with immediate updates
  const expensePercentage = calculatePercentage(totalExpenses, Math.max(totalExpenses + Math.max(0, profit), 1));
  const profitPercentage = profit > 0 ? calculatePercentage(profit, totalExpenses + profit) : 0;

  const resetAll = () => {
    setExpenses(expenses.map(e => ({ ...e, value: 0 })));
    setIncomes(incomes.map(i => ({ ...i, value: 0 })));
    setTicketDetails({ quantity: 50, price: 10 });
    setIsAutoBudget(false);
    setManualExpenses([]); // Clear manual adjustments
  };

  // Update tooltip content to reflect new fixed-cost model
  const getExpenseTooltip = (expenseName: string) => {
    const costs = FIXED_COSTS[expenseName as ExpenseCategory];
    return `Fixed costs based on event size:
            • Small (≤100): $${costs.SMALL.toLocaleString()}
            • Medium (≤250): $${costs.MEDIUM.toLocaleString()}
            • Large (≤500): $${costs.LARGE.toLocaleString()}
            • XLarge (≤1000): $${costs.XLARGE.toLocaleString()}
            • Huge (1000+): $${costs.HUGE.toLocaleString()}`;
  };

  // Update the Auto-Budget switch tooltip
  const getAutoBudgetTooltip = () => {
    return `Expenses scale differently with ticket quantity:
            • Catering scales fastest with attendance
            • Venue rental scales moderately
            • Marketing scales slower and increases with ticket price
            • Equipment and staffing remain fixed
            • Miscellaneous scales slowest
            
            All scaling costs grow exponentially but at different rates.
            You can still manually adjust values in auto-budget mode.`;
  };

  return (
    <div className="min-h-screen bg-[#0B0D13]">
      <style>{inputStyles}</style>
      <div className="h-full max-w-7xl mx-auto flex flex-col space-y-4 p-3 sm:p-4 md:p-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h1 className="text-lg sm:text-xl font-semibold text-[#E5E7EB]">Event Budget Calculator</h1>
          <Button
            variant="outline"
            onClick={resetAll}
            className="h-8 px-3 text-xs bg-transparent border-[#2D3139] text-[#E5E7EB] hover:bg-[#1D2027]"
          >
            Reset All
          </Button>
        </div>

        {/* Sticky Budget Summary for Mobile/Tablet */}
        <div className="lg:hidden sticky top-0 z-50 -mx-3 sm:-mx-4 px-3 sm:px-4 py-2 bg-[#0B0D13]/80 backdrop-blur-lg transform transition-all duration-300 ease-in-out">
          <div className="grid grid-cols-1 gap-2">
            {/* Net Profit - Featured at top */}
            <div className={`bg-gradient-to-br ${profit >= 0 ? 'from-[#1A2428]/90 to-[#1A2C25]/90' : 'from-[#2C1A1A]/90 to-[#1A1D24]/90'} rounded-xl p-3 border border-[#2D3139] shadow-xl relative overflow-hidden`}>
              <div className="flex flex-col relative z-10">
                <span className="text-[#9CA3AF] text-sm mb-1">Net Profit</span>
                <span className={`text-xl sm:text-2xl font-bold tracking-tight ${profit >= 0 ? 'text-[#4aba91]' : 'text-[#dc6868]'}`}>
                  ${profit.toLocaleString()}
                </span>
              </div>
              {/* Decorative elements */}
              <div className={`absolute top-0 right-0 w-24 h-24 opacity-10 transform translate-x-12 -translate-y-6 rounded-full blur-2xl ${profit >= 0 ? 'bg-[#4aba91]' : 'bg-[#dc6868]'}`} />
            </div>

            {/* Income and Expenses Row */}
            <div className="grid grid-cols-2 gap-2">
              {/* Total Income */}
              <div className="bg-[#1A1D24]/90 rounded-lg p-2 border border-[#2D3139] shadow-lg">
                <div className="flex flex-col">
                  <span className="text-[#9CA3AF] text-xs">Total Income</span>
                  <span className="text-[#4aba91] text-sm font-medium">
                    ${totalIncome.toLocaleString()}
                  </span>
                </div>
              </div>

              {/* Total Expenses */}
              <div className="bg-[#1A1D24]/90 rounded-lg p-2 border border-[#2D3139] shadow-lg">
                <div className="flex flex-col">
                  <span className="text-[#9CA3AF] text-xs">Total Expenses</span>
                  <span className="text-[#dc6868] text-sm font-medium">
                    ${totalExpenses.toLocaleString()}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Budget Report */}
        <div className="bg-[#1D2027] rounded-lg border border-[#2D3139]">
          <div className="p-4 space-y-4">
            {/* Two-tone Bar Graph */}
            <div className="h-2 flex rounded-sm overflow-hidden bg-[#2D3139] transition-all duration-200">
              <div 
                className="bg-[#dc6868] transition-all duration-200" 
                style={{ width: `${expensePercentage}%` }} 
              />
              {profit > 0 && (
                <div 
                  className="bg-[#4aba91] transition-all duration-200" 
                  style={{ width: `${profitPercentage}%` }} 
                />
              )}
            </div>

            {/* Budget Summary and Report Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-4">
              {/* Detailed Budget Report */}
              <div className="lg:col-span-8 space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  {/* Income Breakdown */}
                  <div className="space-y-2">
                    <h3 className="font-medium text-[#E5E7EB] text-sm">Income Breakdown</h3>
                    <div className="space-y-1.5">
                      <div className="flex justify-between items-center">
                        <span className="text-[#9CA3AF] text-sm">Ticket Sales</span>
                        <span className="text-[#4aba91] text-sm font-medium">${(ticketDetails.quantity * ticketDetails.price).toLocaleString()}</span>
                      </div>
                      {incomes.map(income => (
                        income.name !== 'Ticket Sales' && (
                          <div key={income.name} className="flex justify-between items-center">
                            <span className="text-[#9CA3AF] text-sm">{income.name}</span>
                            <span className="text-[#4aba91] text-sm font-medium">${income.value.toLocaleString()}</span>
                          </div>
                        )
                      ))}
                    </div>
                  </div>

                  {/* Expense Breakdown */}
                  <div className="space-y-2">
                    <h3 className="font-medium text-[#E5E7EB] text-sm">Expense Breakdown</h3>
                    <div className="space-y-1.5">
                      {expenses.map((expense, index) => (
                        <div key={expense.name} className="flex justify-between items-center">
                          <TooltipProvider>
                            <Tooltip>
                              <TooltipTrigger asChild>
                                <label className="text-sm text-[#9CA3AF] cursor-help">
                                  {expense.name}
                                </label>
                              </TooltipTrigger>
                              <TooltipContent side="right" className="max-w-[200px]">
                                <p className="text-xs">{getExpenseTooltip(expense.name)}</p>
                              </TooltipContent>
                            </Tooltip>
                          </TooltipProvider>
                          <span className="text-[#dc6868] text-sm font-medium">${expense.value.toLocaleString()}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>

              {/* Budget Summary Cards - Desktop Only */}
              <div className="hidden lg:grid lg:col-span-4 grid-cols-1 gap-3">
                {/* Net Profit - Moved to top for emphasis */}
                <div className={`order-first col-span-1 bg-gradient-to-br ${profit >= 0 ? 'from-[#1A2428] to-[#1A2C25]' : 'from-[#2C1A1A] to-[#1A1D24]'} rounded-xl p-4 border border-[#2D3139] shadow-xl relative overflow-hidden`}>
                  <div className="flex flex-col relative z-10">
                    <span className="text-[#9CA3AF] text-sm mb-1">Net Profit</span>
                    <span className={`text-2xl sm:text-3xl lg:text-4xl font-bold tracking-tight ${profit >= 0 ? 'text-[#4aba91]' : 'text-[#dc6868]'}`}>
                      ${profit.toLocaleString()}
                    </span>
                  </div>
                  {/* Decorative elements */}
                  <div className={`absolute top-0 right-0 w-32 h-32 opacity-10 transform translate-x-16 -translate-y-8 rounded-full blur-2xl ${profit >= 0 ? 'bg-[#4aba91]' : 'bg-[#dc6868]'}`} />
                </div>

                {/* Total Income */}
                <div className="bg-[#1A1D24] rounded-lg p-3 border border-[#2D3139]">
                  <div className="flex flex-col">
                    <span className="text-[#9CA3AF] text-xs sm:text-sm">Total Income</span>
                    <span className="text-[#4aba91] text-base sm:text-lg lg:text-xl font-medium">
                      ${totalIncome.toLocaleString()}
                    </span>
                  </div>
                </div>

                {/* Total Expenses */}
                <div className="bg-[#1A1D24] rounded-lg p-3 border border-[#2D3139]">
                  <div className="flex flex-col">
                    <span className="text-[#9CA3AF] text-xs sm:text-sm">Total Expenses</span>
                    <span className="text-[#dc6868] text-base sm:text-lg lg:text-xl font-medium">
                      ${totalExpenses.toLocaleString()}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Main Content Grid */}
        <div className="flex-1 grid grid-cols-1 lg:grid-cols-2 gap-4 min-h-0">
          {/* Income Section */}
          <div className="bg-[#1D2027] rounded-lg border border-[#2D3139] flex flex-col">
            <div className="flex items-center justify-between p-4 border-b border-[#2D3139]">
              <span className="text-sm font-semibold text-[#E5E7EB]">Income</span>
            </div>
            <div className="flex-1 overflow-y-auto p-4">
              <div className="space-y-4">
                {/* Ticket Calculator */}
                <div className="space-y-4 border-b border-[#2D3139] pb-4">
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <label className="text-sm text-[#9CA3AF]">Number of Tickets</label>
                      <Input
                        type="number"
                        value={ticketDetails.quantity}
                        onChange={(e) => {
                          const value = parseInt(e.target.value) || 0;
                          setTicketDetails(prev => ({ ...prev, quantity: Math.min(Math.max(value, 0), 1000) }));
                        }}
                        className="h-8 w-24 text-right text-sm bg-[#2D3139] border-[#3D4149] text-[#4aba91]"
                        min={0}
                        max={1000}
                        step={1}
                      />
                    </div>
                    <div 
                      className="w-full relative"
                      onMouseDown={handleMouseDown(() => handleTicketDetailDoubleClick('quantity'))}
                    >
                      <Slider
                        value={[ticketDetails.quantity]}
                        min={0}
                        max={1000}
                        step={1}
                        onValueChange={([value]) => setTicketDetails(prev => ({ ...prev, quantity: value }))}
                        className="h-1.5"
                        variant="income"
                      />
                    </div>
                  </div>

                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <label className="text-sm text-[#9CA3AF]">Ticket Price</label>
                      <div className="flex items-center space-x-1">
                        <span className="text-xs text-[#4aba91]">$</span>
                        <Input
                          type="number"
                          value={ticketDetails.price}
                          onChange={(e) => {
                            const value = parseFloat(e.target.value) || 0;
                            setTicketDetails(prev => ({ ...prev, price: Math.min(Math.max(value, 0), 200) }));
                          }}
                          className="h-8 w-24 text-right text-sm bg-[#2D3139] border-[#3D4149] text-[#4aba91]"
                          min={0}
                          max={200}
                          step={1}
                        />
                      </div>
                    </div>
                    <div 
                      className="w-full relative"
                      onMouseDown={handleMouseDown(() => handleTicketDetailDoubleClick('price'))}
                    >
                      <Slider
                        value={[ticketDetails.price]}
                        min={0}
                        max={200}
                        step={1}
                        onValueChange={([value]) => setTicketDetails(prev => ({ ...prev, price: value }))}
                        className="h-1.5"
                        variant="income"
                      />
                    </div>
                  </div>

                  <div className="flex justify-between items-center">
                    <span className="text-sm text-[#9CA3AF]">Total Ticket Sales</span>
                    <span className="text-sm font-medium text-[#4aba91]">
                      ${(ticketDetails.quantity * ticketDetails.price).toLocaleString()}
                    </span>
                  </div>
                </div>

                {/* Other Income Sources */}
                {incomes.map((income, index) => (
                  income.name !== 'Ticket Sales' && (
                    <div key={income.name} className="space-y-3">
                      <div className="flex justify-between items-center">
                        <label className="text-sm text-[#9CA3AF]">{income.name}</label>
                        <div className="flex items-center space-x-1">
                          <span className="text-xs text-[#10B981]">$</span>
                          <Input
                            type="number"
                            value={income.value}
                            onChange={(e) => handleIncomeChange(index, parseFloat(e.target.value) || 0)}
                            className="h-8 w-24 text-right text-sm bg-[#2D3139] border-[#3D4149] text-[#10B981]"
                            min={income.min}
                            max={income.max}
                            step={income.step}
                          />
                        </div>
                      </div>
                      <div 
                        className="w-full relative"
                        onMouseDown={handleMouseDown(() => handleIncomeDoubleClick(index))}
                      >
                        <Slider
                          value={[income.value]}
                          min={income.min}
                          max={income.max}
                          step={income.step}
                          onValueChange={(value) => handleIncomeChange(index, value[0])}
                          className="income-slider h-1.5"
                          variant="income"
                        />
                      </div>
                    </div>
                  )
                ))}
              </div>
            </div>
          </div>

          {/* Expenses Section */}
          <div className="bg-[#1D2027] rounded-lg border border-[#2D3139] flex flex-col">
            <div className="flex items-center justify-between p-4 border-b border-[#2D3139]">
              <span className="text-sm font-semibold text-[#E5E7EB]">Expenses</span>
              <TooltipProvider>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <div className="flex items-center space-x-2">
                      <span className="text-xs text-[#9CA3AF]">Auto-Budget</span>
                      <Switch
                        checked={isAutoBudget}
                        onCheckedChange={setIsAutoBudget}
                        className="scale-90"
                      />
                    </div>
                  </TooltipTrigger>
                  <TooltipContent side="left" className="max-w-[300px] whitespace-pre-line">
                    <p className="text-xs">{getAutoBudgetTooltip()}</p>
                  </TooltipContent>
                </Tooltip>
              </TooltipProvider>
            </div>
            <div className="flex-1 overflow-y-auto p-4">
              <div className="space-y-4">
                {expenses.map((expense, index) => (
                  <div key={expense.name} className="space-y-3">
                    <div className="flex justify-between items-center">
                      <TooltipProvider>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <label className="text-sm text-[#9CA3AF] cursor-help">
                              {expense.name}
                            </label>
                          </TooltipTrigger>
                          <TooltipContent side="right" className="max-w-[200px]">
                            <p className="text-xs">{getExpenseTooltip(expense.name)}</p>
                          </TooltipContent>
                        </Tooltip>
                      </TooltipProvider>
                      <div className="flex items-center space-x-1">
                        <span className="text-xs text-[#dc6868]">$</span>
                        <Input
                          type="number"
                          value={expense.value}
                          onChange={(e) => handleExpenseChange(index, parseFloat(e.target.value) || 0)}
                          className="h-8 w-24 text-right text-sm bg-[#2D3139] border-[#3D4149] text-[#dc6868]"
                          min={expense.min}
                          max={expense.max}
                          step={expense.step}
                        />
                      </div>
                    </div>
                    <div 
                      className="w-full relative"
                      onMouseDown={handleMouseDown(() => handleExpenseDoubleClick(index))}
                    >
                      <Slider
                        value={[expense.value]}
                        min={expense.min}
                        max={expense.max}
                        step={expense.step}
                        onValueChange={(value) => handleExpenseChange(index, value[0])}
                        className="expense-slider h-1.5"
                        variant="expense"
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default EventCalculator; 