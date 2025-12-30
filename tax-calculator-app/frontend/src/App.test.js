import { render, screen } from '@testing-library/react';
import App from './App';

describe('Tax Calculator App', () => {
  test('renders without crashing', () => {
    render(<App />);
  });

  test('contains tax calculator elements', () => {
    render(<App />);
    // Check if main heading exists
    const heading = screen.getByRole('heading');
    expect(heading).toBeInTheDocument();
  });

  test('has input field for income', () => {
    render(<App />);
    // Check for any input field
    const inputs = screen.getAllByRole('textbox');
    expect(inputs.length).toBeGreaterThan(0);
  });
});
