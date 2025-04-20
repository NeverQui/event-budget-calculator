# Event Calculator App

A modern, responsive web application for event budget planning and management. Built with React, TypeScript, and Tailwind CSS, featuring a sleek dark theme interface and real-time calculations.

## Features

- **Real-time Budget Calculations**
  - Dynamic income and expense tracking
  - Automatic profit/loss calculation
  - Visual progress bar showing budget distribution

- **Smart Auto-Budget Feature**
  - Automatic expense allocation based on industry standards:
    - Venue Rental: 25%
    - Catering: 30%
    - Equipment: 5%
    - Staffing: 5%
    - Marketing: 10%
    - Miscellaneous: 5%
    - Profit Buffer: 20%

- **Income Management**
  - Ticket sales calculator with quantity and price controls
  - Additional income sources:
    - Sponsorships
    - Merchandise
    - Donations

- **Expense Management**
  - Detailed expense categories
  - Adjustable sliders with precise controls
  - Double-click rounding feature for convenient value adjustments

- **Modern UI Components**
  - Responsive design that works on all devices
  - Interactive sliders and inputs
  - Real-time visual feedback
  - Dark theme optimized for reduced eye strain

## Getting Started

### Prerequisites

- Node.js (v14 or higher)
- npm or yarn

### Installation

1. Clone the repository:
   ```bash
   git clone [repository-url]
   cd event-calculator-app
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm run dev
   ```

4. Open your browser and navigate to:
   ```
   http://localhost:5173
   ```

## Usage

1. **Setting Up Event Income**
   - Enter the number of tickets and price per ticket
   - Add additional income from sponsorships, merchandise, or donations
   - Watch the total income update in real-time

2. **Managing Expenses**
   - Use sliders to adjust expense values
   - Toggle auto-budget to automatically allocate expenses based on total income
   - Double-click any slider to round to the nearest step value

3. **Monitoring Profit**
   - Track your net profit in real-time
   - Visual progress bar shows the ratio of expenses to profit
   - Color-coded indicators (green for profit, red for loss)

## Built With

- [React](https://reactjs.org/) - Frontend framework
- [TypeScript](https://www.typescriptlang.org/) - Type safety and enhanced developer experience
- [Tailwind CSS](https://tailwindcss.com/) - Utility-first CSS framework
- [Vite](https://vitejs.dev/) - Next generation frontend tooling
- [Radix UI](https://www.radix-ui.com/) - Unstyled, accessible UI components
- [shadcn/ui](https://ui.shadcn.com/) - Re-usable UI components

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 