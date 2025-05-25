import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/models/event.dart';

class PurchaseHistoryEventCard extends StatelessWidget {
  final Event event;
  final int userId;

  const PurchaseHistoryEventCard({super.key, required this.event, required this.userId});

  int getTotalPrice(Event event) {
    int totalPrice = 0;
    for(int i=0; i<event.tickets.length; i++){
      totalPrice += event.tickets[i]['price'] as int;
    }
    return totalPrice;
  }
 
  @override
  Widget build(BuildContext context) {
    int totalPrice = getTotalPrice(event);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4, // Add elevation for a modern look
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Rounded corners
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Category: ',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        TextSpan(
                          text: '${event.category}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.normal
                          ),
                        ),
                      ]
                    )
                  ),

                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Tickets: ',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        TextSpan(
                          text: '${event.tickets.length}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.normal
                          ),
                        ),
                      ]
                    )
                  ),

                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Total Price: ',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        TextSpan(
                          text: (totalPrice != 0) ? '${totalPrice}' : "Free",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.normal
                          ),
                        ),
                      ]
                    )
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}