import { Observable } from '@nativescript/core';

export class HomeViewModel extends Observable {
    private _featuredEvents: any[];
    private _categories: any[];

    constructor() {
        super();
        
        // Initialize with sample data
        this._featuredEvents = [
            { name: 'Summer Music Festival', date: '2024-07-15', price: '$49.99' },
            { name: 'Comedy Night', date: '2024-06-20', price: '$29.99' },
            { name: 'Theater Show', date: '2024-06-25', price: '$39.99' }
        ];

        this._categories = [
            { name: 'Concerts' },
            { name: 'Sports' },
            { name: 'Theater' },
            { name: 'Festivals' }
        ];

        this.notifyPropertyChange('featuredEvents', this._featuredEvents);
        this.notifyPropertyChange('categories', this._categories);
    }

    get featuredEvents(): any[] {
        return this._featuredEvents;
    }

    get categories(): any[] {
        return this._categories;
    }

    onCategoryTap(args: any) {
        const category = args.object.bindingContext;
        // Navigate to category events page
        console.log(`Selected category: ${category.name}`);
    }
}