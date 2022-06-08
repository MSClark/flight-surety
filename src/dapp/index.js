
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async () => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        DOM.elid('buy-insurance').addEventListener('click', () => {
            let flightName = DOM.elid('flight-name').value;
            let airlineAddress = DOM.elid('insurance-airline-address').value;
            let flightTimestamp = DOM.elid('flight-timestamp').value;
            let insuredAmount = DOM.elid('insurance-amount').value;
            contract.buy(flightName, flightTimestamp, airlineAddress, insuredAmount, (error, result) => {
                displayTx('display-wrapper-buy', [{ label: 'Insurance purchased Tx', error: error, value: result }]);
                DOM.elid('insurance-airline-address').value = "";
                DOM.elid('flight-name').value = "";
                DOM.elid('insurance-amount').value = "";
                DOM.elid('flight-timestamp').value = "";
            });
        })

        DOM.elid('flight-status').addEventListener('click', () => {
            let airlineAddress = DOM.elid('insurance-airline-address').value;
            let flightName = DOM.elid('flight-name').value;
            let flightTimestamp = DOM.elid('flight-timestamp').value;
            contract.fetchFlightStatus(flightName, airlineAddress, flightTimestamp, (error, result) => {
                displayTx('display-wrapper-buy', [{ label: 'Fetch flight status', error: error, value: "fetching complete" }]);
                DOM.elid('insurance-airline-address').value = "";
                DOM.elid('flight-name').value = "";
                DOM.elid('flight-timestamp').value = "";
            });
        })

        DOM.elid('check-credit').addEventListener('click', () => {
            let passengerAddress = DOM.elid('passenger-address').value;
            contract.getPassengerCredit(passengerAddress, (error, result) => {
                displayTx('display-wrapper-passenger-detail', [{ label: 'Credit pending to withdraw', error: error, value: result + ' ETH' }]);
                DOM.elid('passenger-address').value = "";
            });
        })

        DOM.elid('withdraw-credit').addEventListener('click', () => {
            let passengerAddress = DOM.elid('passenger-address').value;
            contract.withdrawCredits(passengerAddress, (error, result) => {
                displayTx('display-wrapper-passenger-detail', [{ label: 'Credit withdrawn', error: error, value: result + ' ETH' }]);
                DOM.elid('passenger-address').value = "";
            });
        });

    });
})();

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}

function displayTx(id, results) {
    let displayDiv = DOM.elid(id);
    results.map((result) => {
        let row = displayDiv.appendChild(DOM.div({ className: 'row' }));
        row.appendChild(DOM.div({ className: 'col-sm-3 field' }, result.error ? result.label + " Error" : result.label));
        row.appendChild(DOM.div({ className: 'col-sm-9 field-value' }, result.error ? String(result.error) : String(result.value)));
        displayDiv.appendChild(row);
    })
}
