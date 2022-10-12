import React, { Component } from 'react';

export class FetchData extends Component {
  static displayName = FetchData.name;

  constructor(props) {
    super(props);
    this.state = { forecasts: [], loading: true };
  }

  componentDidMount() {
    this.populateWeatherData();
  }

  static renderForecastsTable(forecasts) {
    return (
      <table className='table table-striped' aria-labelledby="tabelLabel">
        <thead>
          <tr>
            <th>Date</th>
            <th>Temp. (C)</th>
            <th>Temp. (F)</th>
            <th>Summary</th>
          </tr>
        </thead>
        <tbody>
          {forecasts.map(forecast =>
            <tr key={forecast.date}>
              <td>{forecast.date}</td>
              <td>{forecast.temperatureC}</td>
              <td>{forecast.temperatureF}</td>
              <td>{forecast.summary}</td>
            </tr>
          )}
        </tbody>
      </table>
    );
  }

  render() {
    let contents = this.state.loading
      ? <p><em>Loading...</em></p>
      : FetchData.renderForecastsTable(this.state.forecasts);

    return (
      <div>
        <h1 id="tabelLabel" >Weather forecast</h1>
        <p>This component demonstrates fetching data from the server.</p>
        {contents}
        <p><button className="btn btn-primary" onClick={() => this.populateWeatherData()}>Refresh</button></p>
        <p><button className="btn btn-primary" onClick={() => this.exampleError()}>Error</button></p>
      </div>
    );
  }

  async populateWeatherData() {
    const response = await fetch('weatherforecast');
    const data = await response.json();
    this.setState({ forecasts: data, loading: false });
  }

  async exampleError() {
    try {
      const response = await fetch('weatherforecast/throw');
      if (!response.ok) {
        const problem = await response.json();
        const errorMessage = `Problem: ${problem.status} ${problem.title}. Check the logs for trace identifier ${problem.traceId.substr(3, 32)} at ${new Date()}.`;
        console.error(errorMessage);
        throw new Error(errorMessage, { cause: problem });
      }
      const data = await response.json();
      this.setState({ forecasts: data, loading: false });
    } catch (error) {
      alert(`${error.name}\n${error.message}\n${error.cause?.detail||''}`);
    }
  }
}
