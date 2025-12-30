import React, { useState, useEffect } from 'react';
import './App.css';

const API_URL = '';

function App() {
  const [income, setIncome] = useState('');
  const [niNumber, setNiNumber] = useState('');
  const [result, setResult] = useState(null);
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [health, setHealth] = useState(null);

  useEffect(() => {
    checkHealth();
    fetchHistory();
  }, []);

  const checkHealth = async () => {
    try {
      const response = await fetch(`${API_URL}/health`);
      const data = await response.json();
      setHealth(data);
    } catch (err) {
      console.error('Health check failed:', err);
    }
  };

  const fetchHistory = async () => {
    try {
      const response = await fetch(`${API_URL}/api/history`);
      const data = await response.json();
      setHistory(data || []);
    } catch (err) {
      console.error('Failed to fetch history:', err);
    }
  };

  const calculateTax = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await fetch(`${API_URL}/api/calculate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          income: parseFloat(income),
          national_insurance: niNumber,
          tax_year: '2024/2025',
        }),
      });

      if (!response.ok) {
        throw new Error('Calculation failed');
      }

      const data = await response.json();
      setResult(data);
      fetchHistory(); // Refresh history
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
    }).format(amount);
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleString('en-GB');
  };

  return (
    <div className='App'>
      <header className='App-header'>
        <h1>UK Tax Calculator</h1>
        <p className='subtitle'>
          HMRC-Style Tax Calculation Demo with HashiCorp Vault
        </p>
        {health && (
          <div
            className={`health-status ${
              health.status === 'healthy' ? 'healthy' : 'unhealthy'
            }`}
          >
            <span>🔒 Vault: {health.vault.split(':')[0]}</span>
            <span>💾 Database: {health.database.split(':')[0]}</span>
          </div>
        )}
      </header>

      <div className='container'>
        <div className='calculator-section'>
          <h2>Calculate Your Tax</h2>
          <form onSubmit={calculateTax}>
            <div className='form-group'>
              <label htmlFor='income'>
                Annual Income (£)
                <span className='tooltip'>
                  ℹ️
                  <span className='tooltiptext'>
                    Enter your gross annual salary
                  </span>
                </span>
              </label>
              <input
                id='income'
                type='number'
                value={income}
                onChange={(e) => setIncome(e.target.value)}
                placeholder='e.g., 50000'
                required
                min='0'
                step='0.01'
              />
            </div>

            <div className='form-group'>
              <label htmlFor='ni'>
                National Insurance Number
                <span className='tooltip'>
                  ℹ️
                  <span className='tooltiptext'>
                    Encrypted with Vault Transit Engine
                  </span>
                </span>
              </label>
              <input
                id='ni'
                type='text'
                value={niNumber}
                onChange={(e) => setNiNumber(e.target.value)}
                placeholder='e.g., AB123456C'
                required
                pattern='[A-Z]{2}[0-9]{6}[A-D]'
                title='Format: 2 letters, 6 numbers, 1 letter (A-D)'
              />
              <small className='security-note'>
                🔒 Encrypted at rest using Vault Transit Engine
              </small>
            </div>

            <button
              type='submit'
              disabled={loading}
              className='calculate-button'
            >
              {loading ? 'Calculating...' : 'Calculate Tax'}
            </button>
          </form>

          {error && <div className='error-message'>❌ Error: {error}</div>}

          {result && (
            <div className='result-card'>
              <h3>Tax Calculation Result</h3>
              <div className='result-grid'>
                <div className='result-item'>
                  <span className='label'>Gross Income:</span>
                  <span className='value'>{formatCurrency(result.income)}</span>
                </div>
                <div className='result-item highlight'>
                  <span className='label'>Income Tax:</span>
                  <span className='value negative'>
                    -{formatCurrency(result.income_tax)}
                  </span>
                </div>
                <div className='result-item highlight'>
                  <span className='label'>National Insurance:</span>
                  <span className='value negative'>
                    -{formatCurrency(result.national_insurance_contribution)}
                  </span>
                </div>
                <div className='result-item total'>
                  <span className='label'>Take Home Pay:</span>
                  <span className='value positive'>
                    {formatCurrency(result.take_home)}
                  </span>
                </div>
                <div className='result-item'>
                  <span className='label'>Effective Tax Rate:</span>
                  <span className='value'>
                    {result.effective_rate.toFixed(2)}%
                  </span>
                </div>
              </div>
              <div className='encrypted-info'>
                <h4>🔐 Security Information</h4>
                <p>
                  <strong>Calculation ID:</strong> {result.id}
                </p>
                <p>
                  <strong>Encrypted NI:</strong>{' '}
                  <code>{result.encrypted_ni.substring(0, 40)}...</code>
                </p>
                <small>
                  National Insurance number is encrypted using Vault Transit
                  Engine before storage
                </small>
              </div>
            </div>
          )}
        </div>

        <div className='history-section'>
          <h2>Calculation History</h2>
          <p className='history-subtitle'>
            Recent calculations (showing last 50)
          </p>
          {history.length === 0 ? (
            <div className='empty-state'>
              <p>No calculations yet. Try calculating your tax above!</p>
            </div>
          ) : (
            <div className='history-list'>
              {history.map((item, index) => (
                <div key={item.id || index} className='history-item'>
                  <div className='history-header'>
                    <span className='history-income'>
                      {formatCurrency(item.income)}
                    </span>
                    <span className='history-date'>
                      {formatDate(item.timestamp)}
                    </span>
                  </div>
                  <div className='history-details'>
                    <span>Tax: {formatCurrency(item.income_tax)}</span>
                    <span>
                      NI: {formatCurrency(item.national_insurance_contribution)}
                    </span>
                    <span className='history-takehome'>
                      Take home: {formatCurrency(item.take_home)}
                    </span>
                  </div>
                  <div className='history-encrypted'>
                    <small>🔒 Encrypted NI: {item.encrypted_ni}</small>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <footer className='App-footer'>
        <div className='vault-badge'>
          <span>🔐 Powered by HashiCorp Vault</span>
        </div>
        <div className='security-features'>
          <div className='feature'>
            <strong>Dynamic Credentials</strong>
            <small>Database credentials from Vault</small>
          </div>
          <div className='feature'>
            <strong>Transit Encryption</strong>
            <small>PII encrypted at rest</small>
          </div>
          <div className='feature'>
            <strong>Kubernetes Auth</strong>
            <small>Pod-level identity</small>
          </div>
          <div className='feature'>
            <strong>Audit Logging</strong>
            <small>Complete compliance trail</small>
          </div>
        </div>
        <p className='disclaimer'>
          Demo application for calculating Tax rates: UK 2024/2025
        </p>
      </footer>
    </div>
  );
}

export default App;
