import App from './App';

describe('Tax Calculator App', () => {
  test('App component exists', () => {
    expect(App).toBeDefined();
  });

  test('App is a function', () => {
    expect(typeof App).toBe('function');
  });
});
