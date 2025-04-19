import React from 'react';
import EventCalculator from './components/EventCalculator';
import './index.css';

const App: React.FC = () => {
  return (
    <main className="min-h-screen bg-background">
      <EventCalculator />
    </main>
  );
};

export default App; 