import { LightningElement, api, wire, track } from 'lwc';
import { getRecordUi } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import getStatusTimeTracker from '@salesforce/apex/TrackStatusHoursController.getStatusTimeTracker';

export default class LpitrackStatusHours extends LightningElement {
    @api objectApiName;
    @api fields;
    @track currentphase = '';
    @track error;
    @api recordId;
    @track objectName;
    @track statusList = [];
    timerRef;
    @track timer = '0 days, 0 hours, 0 minutes, 0 seconds';
    wiredTrackerResponse;

    @wire(getRecordUi, { recordIds: '$recordId', layoutTypes: ['Full'], modes: ['View'] })
    wiredRecordUi({ data, error }) {
        if (data) {
            this.objectName = data.records[this.recordId].apiName;
            this.fetchStatusTimeTracker();
        } else if (error) {
            console.error('Error fetching object name:', error);
        }
    }

    @wire(getStatusTimeTracker, { objectName: '$objectApiName', recordId: '$recordId', fieldName: 'OldValue,NewValue,Field,CreatedDate', filterFieldName:'$fields'})
    wiredStatusTimeTracker(response) {
        this.wiredTrackerResponse = response;
        const { data, error } = response;
        if (data) {
            this.processTrackerData(data);
        } else if (error) {
            this.error = error;
        }
    }

    fetchStatusTimeTracker() {
        refreshApex(this.wiredTrackerResponse);
    }

    processTrackerData(data) {
        this.statusList = Object.entries(data)
            .filter(([key]) => key !== "latestCreatedDateTime" && key !== "latestStatusValue")
            .map(([key, value]) => ({ label: key, value: value }));

        this.currentphase = data.latestStatusValue;
        this.startTimer(Number(data.latestCreatedDateTime));
    }

    startTimer(elapsedSeconds) {
        if (isNaN(elapsedSeconds)) {
            console.error('Invalid number format:', elapsedSeconds);
            return;
        }

        clearInterval(this.timerRef);
        this.timerRef = setInterval(() => {
            elapsedSeconds++;
            this.timer = this.secondToHms(elapsedSeconds);
        }, 1000);
    }

    secondToHms(d) {
        const days = Math.floor(d / 86400);
        const hours = Math.floor((d % 86400) / 3600);
        const minutes = Math.floor((d % 3600) / 60);
        const seconds = d % 60;

        return `${days} days, ${hours} hours, ${minutes} minutes, ${seconds} seconds`;
    }

    disconnectedCallback() {
        clearInterval(this.timerRef);
    }
}