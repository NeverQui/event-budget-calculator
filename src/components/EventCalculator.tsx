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
      // Double click detected
      e.preventDefault();
      callback();
    }
    
    setLastClickTime(currentTime);
  };

  // Store manual expenses when switching to auto-budget
  useEffect(() => {
    if (isAutoBudget) {
      setManualExpenses([...expenses]);
      // Calculate initial auto-budget values but don't lock them
      const totalIncome = incomes.reduce((sum, item) => sum + item.value, 0);
      const newExpenses = expenses.map(expense => ({
        ...expense,
        value: roundToNearest5(Math.round((BUDGET_PERCENTAGES[expense.name as keyof typeof BUDGET_PERCENTAGES] / 100) * totalIncome))
      }));
      setExpenses(newExpenses);
    } else if (manualExpenses.length > 0) {
      setExpenses(manualExpenses);
    }
  }, [isAutoBudget, incomes]);

  // Update ticket sales and auto-budget calculations
  useEffect(() => {
    const totalTicketSales = ticketDetails.quantity * ticketDetails.price;
    const newIncomes = [...incomes];
    const ticketSalesIndex = newIncomes.findIndex(income => income.name === 'Ticket Sales');
    newIncomes[ticketSalesIndex].value = totalTicketSales;
    setIncomes(newIncomes);

    if (isAutoBudget) {
      const totalIncome = newIncomes.reduce((sum, item) => sum + item.value, 0);
      const newExpenses = expenses.map(expense => ({
        ...expense,
        value: roundToNearest5(Math.round((BUDGET_PERCENTAGES[expense.name as keyof typeof BUDGET_PERCENTAGES] / 100) * totalIncome))
      }));
      setExpenses(newExpenses);
    }
  }, [ticketDetails, isAutoBudget && incomes.filter(i => i.name !== 'Ticket Sales').map(i => i.value).join(',')]);

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
  };

  const handleExpenseDoubleClick = (index: number) => {
    const expense = expenses[index];
    const roundedValue = roundToNearestStep(expense.value, expense.step);
    handleExpenseChange(index, roundedValue);
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
  };

  return (
    <div className="min-h-screen bg-[#0B0D13]">
      <style>{inputStyles}</style>
      <div className="h-full max-w-7xl mx-auto flex flex-col space-y-4 p-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-semibold text-[#E5E7EB]">Event Budget Calculator</h1>
          <Button
            variant="outline"
            onClick={resetAll}
            className="h-8 px-3 text-xs bg-transparent border-[#2D3139] text-[#E5E7EB] hover:bg-[#1D2027]"
          >
            Reset All
          </Button>
        </div>

        {/* Budget Report */}
        <div className="bg-[#1D2027] rounded-lg border border-[#2D3139]">
          <div className="p-6 space-y-6">
            {/* Two-tone Bar Graph */}
            <div className="h-3 flex rounded-sm overflow-hidden bg-[#2D3139] transition-all duration-200">
              <div 
                className="bg-[#EF4444] transition-all duration-200" 
                style={{ width: `${expensePercentage}%` }} 
              />
              {profit > 0 && (
                <div 
                  className="bg-[#10B981] transition-all duration-200" 
                  style={{ width: `${profitPercentage}%` }} 
                />
              )}
            </div>

            {/* Budget Summary Grid */}
            <div className="grid grid-cols-12 gap-4">
              {/* Total Income */}
              <div className="col-span-3 bg-[#1A1D24] rounded-lg p-4 border border-[#2D3139]">
                <div className="flex flex-col space-y-1">
                  <span className="text-sm text-[#9CA3AF]">Total Income</span>
                  <span className="text-2xl font-medium text-[#10B981]">
                    ${totalIncome.toLocaleString()}
                  </span>
                </div>
              </div>

              {/* Total Expenses */}
              <div className="col-span-3 bg-[#1A1D24] rounded-lg p-4 border border-[#2D3139]">
                <div className="flex flex-col space-y-1">
                  <span className="text-sm text-[#9CA3AF]">Total Expenses</span>
                  <span className="text-2xl font-medium text-[#EF4444]">
                    ${totalExpenses.toLocaleString()}
                  </span>
                </div>
              </div>

              {/* Net Profit */}
              <div className="col-span-6 bg-[#1A1D24] rounded-lg p-4 border border-[#2D3139]">
                <div className="flex flex-col space-y-1">
                  <span className="text-sm text-[#9CA3AF]">Net Profit</span>
                  <span className={`text-4xl font-semibold ${profit >= 0 ? 'text-[#10B981]' : 'text-[#EF4444]'}`}>
                    ${profit.toLocaleString()}
                  </span>
                </div>
              </div>
            </div>

            {/* Detailed Budget Report */}
            <div className="grid grid-cols-12 gap-4 text-sm">
              {/* Income Breakdown */}
              <div className="col-span-6 space-y-2">
                <h3 className="font-medium text-[#E5E7EB]">Income Breakdown</h3>
                <div className="space-y-1">
                  <div className="flex justify-between">
                    <span className="text-[#9CA3AF]">Ticket Sales</span>
                    <span className="text-[#10B981]">${(ticketDetails.quantity * ticketDetails.price).toLocaleString()}</span>
                  </div>
                  {incomes.map(income => (
                    income.name !== 'Ticket Sales' && (
                      <div key={income.name} className="flex justify-between">
                        <span className="text-[#9CA3AF]">{income.name}</span>
                        <span className="text-[#10B981]">${income.value.toLocaleString()}</span>
                      </div>
                    )
                  ))}
                </div>
              </div>

              {/* Expense Breakdown */}
              <div className="col-span-6 space-y-2">
                <h3 className="font-medium text-[#E5E7EB]">Expense Breakdown</h3>
                <div className="space-y-1">
                  {expenses.map(expense => (
                    <div key={expense.name} className="flex justify-between">
                      <span className="text-[#9CA3AF]">{expense.name}</span>
                      <span className="text-[#EF4444]">${expense.value.toLocaleString()}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Main Content Grid */}
        <div className="flex-1 grid grid-cols-1 md:grid-cols-2 gap-4 min-h-0">
          {/* Income Section */}
          <div className="bg-[#1D2027] rounded-lg border border-[#2D3139] flex flex-col">
            <div className="flex items-center justify-between p-4 border-b border-[#2D3139]">
              <span className="text-sm font-semibold text-[#E5E7EB]">Income</span>
            </div>
            <div className="flex-1 overflow-y-auto p-4">
              <div className="space-y-4">
                {/* Ticket Calculator */}
                <div className="space-y-4 border-b border-[#2D3139] pb-4">
                  <div className="space-y-2">
                    <div className="flex justify-between items-center">
                      <label className="text-sm text-[#9CA3AF]">Number of Tickets</label>
                      <Input
                        type="number"
                        value={ticketDetails.quantity}
                        onChange={(e) => setTicketDetails(prev => ({ ...prev, quantity: parseInt(e.target.value) || 0 }))}
                        className="h-8 w-20 text-right text-sm bg-[#2D3139] border-[#3D4149] text-[#10B981]"
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
                        onValueChange={(value) => setTicketDetails(prev => ({ ...prev, quantity: value[0] }))}
                        className="income-slider h-1.5"
                      />
                    </div>
                  </div>

                  <div className="space-y-2">
                    <div className="flex justify-between items-center">
                      <label className="text-sm text-[#9CA3AF]">Ticket Price</label>
                      <div className="flex items-center space-x-2">
                        <span className="text-xs text-[#10B981]">$</span>
                        <Input
                          type="number"
                          value={ticketDetails.price}
                          onChange={(e) => setTicketDetails(prev => ({ ...prev, price: parseFloat(e.target.value) || 0 }))}
                          className="h-8 w-20 text-right text-sm bg-[#2D3139] border-[#3D4149] text-[#10B981]"
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
                        onValueChange={(value) => setTicketDetails(prev => ({ ...prev, price: value[0] }))}
                        className="income-slider h-1.5"
                      />
                    </div>
                  </div>

                  <div className="flex justify-between items-center">
                    <span className="text-sm text-[#9CA3AF]">Total Ticket Sales</span>
                    <span className="text-sm font-medium text-[#10B981]">
                      ${(ticketDetails.quantity * ticketDetails.price).toLocaleString()}
                    </span>
                  </div>
                </div>

                {/* Other Income Sources */}
                {incomes.map((income, index) => (
                  income.name !== 'Ticket Sales' && (
                    <div key={income.name} className="space-y-2">
                      <div className="flex justify-between items-center">
                        <label className="text-sm text-[#9CA3AF]">{income.name}</label>
                        <div className="flex items-center space-x-2">
                          <span className="text-xs text-[#10B981]">$</span>
                          <Input
                            type="number"
                            value={income.value}
                            onChange={(e) => handleIncomeChange(index, parseFloat(e.target.value) || 0)}
                            className="h-8 w-20 text-right text-sm bg-[#2D3139] border-[#3D4149] text-[#10B981]"
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
                      />
                    </div>
                  </TooltipTrigger>
                  <TooltipContent>
                    <p>Automatically allocate expenses based on total income</p>
                  </TooltipContent>
                </Tooltip>
              </TooltipProvider>
            </div>
            <div className="flex-1 overflow-y-auto p-4">
              <div className="space-y-4">
                {expenses.map((expense, index) => (
                  <div key={expense.name} className="space-y-2">
                    <div className="flex justify-between items-center">
                      <label className="text-sm text-[#9CA3AF]">{expense.name}</label>
                      <div className="flex items-center space-x-2">
                        <span className="text-xs text-[#EF4444]">$</span>
                        <Input
                          type="number"
                          value={expense.value}
                          onChange={(e) => handleExpenseChange(index, parseFloat(e.target.value) || 0)}
                          className="h-8 w-20 text-right text-sm bg-[#2D3139] border-[#3D4149] text-[#EF4444]"
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