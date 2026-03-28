import 'package:flutter/material.dart';

class BusBookingPage extends StatefulWidget {
  final int userId;
  final int companyId;
  final int officeId;
  final String companyName;
  final String userName;
  final String userPhoneNumber;
  final bool isReplacableScreen;

  const BusBookingPage({super.key, required this.userId, required this.companyId, required this.companyName, required this.officeId, required this.userName, required this.userPhoneNumber, required this.isReplacableScreen});

  @override
  State<BusBookingPage> createState() => _BusBookingPageState();
}

class _BusBookingPageState extends State<BusBookingPage> {
  BusRoute? selectedRoute;

  final List<BusRoute> routes = [
    BusRoute(
      from: "Dar es Salaam",
      to: "Arusha",
      departureTime: "06:00 AM",
      busName: "Kilimanjaro Express",
      price: 35000,
      seatsAvailable: 24,
    ),
    BusRoute(
      from: "Dar es Salaam",
      to: "Mwanza",
      departureTime: "08:30 AM",
      busName: "Royal Coach",
      price: 45000,
      seatsAvailable: 17,
    ),
    BusRoute(
      from: "Dar es Salaam",
      to: "Dodoma",
      departureTime: "07:00 AM",
      busName: "BM Coach",
      price: 30000,
      seatsAvailable: 9,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bus Booking"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: selectedRoute == null
          ? _buildRouteList()
          : _buildTicketPreview(),
    );
  }

// this is my route list, style the card to look as proffessianol and nice as the ones in the image
//   // ================= ROUTE LIST =================
//   Widget _buildRouteList() {
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: routes.length,
//       itemBuilder: (context, index) {
//         final route = routes[index];

//         return Card(
//           elevation: 3,
//           margin: const EdgeInsets.only(bottom: 12),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: InkWell(
//             borderRadius: BorderRadius.circular(12),
//             onTap: () {
//               setState(() {
//                 selectedRoute = route;
//               });
//             },
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(route.from,
//                           style: const TextStyle(
//                               fontSize: 16, fontWeight: FontWeight.bold)),
//                       const Icon(Icons.arrow_forward, color: Colors.grey),
//                       Text(route.to,
//                           style: const TextStyle(
//                               fontSize: 16, fontWeight: FontWeight.bold)),
//                     ],
//                   ),
//                   const SizedBox(height: 10),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text("🕒 ${route.departureTime}"),
//                       Text(route.busName),
//                       Text(
//                         "TZS ${route.price}",
//                         style: const TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.teal),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

// Widget _buildRouteList() {
//   return ListView.builder(
//     padding: const EdgeInsets.all(16),
//     itemCount: routes.length,
//     itemBuilder: (context, index) {
//       final route = routes[index];
//       final isSelected = selectedRoute == route;

//       return AnimatedContainer(
//         duration: const Duration(milliseconds: 250),
//         margin: const EdgeInsets.only(bottom: 14),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(18),
//           boxShadow: [
//             BoxShadow(
//               color: isSelected
//                   ? Colors.teal.withOpacity(0.3)
//                   : Colors.black.withOpacity(0.06),
//               blurRadius: isSelected ? 12 : 6,
//               offset: const Offset(0, 4),
//             ),
//           ],
//           border: Border.all(
//             color: isSelected ? Colors.teal : Colors.grey.shade200,
//             width: isSelected ? 1.5 : 1,
//           ),
//         ),
//         child: InkWell(
//           borderRadius: BorderRadius.circular(18),
//           onTap: () {
//             setState(() {
//               selectedRoute = route;
//             });
//           },
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 // ===== TOP ROW (ROUTE + PRICE) =====
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // ROUTE SECTION
//                     Expanded(
//                       child: Row(
//                         children: [
//                           // FROM
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   "FROM",
//                                   style: TextStyle(
//                                     fontSize: 11,
//                                     color: Colors.grey.shade500,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   route.from,
//                                   style: const TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),

//                           // ARROW
//                           Padding(
//                             padding:
//                                 const EdgeInsets.symmetric(horizontal: 8),
//                             child: Icon(Icons.arrow_forward,
//                                 color: Colors.grey.shade400),
//                           ),

//                           // TO
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.end,
//                               children: [
//                                 Text(
//                                   "TO",
//                                   style: TextStyle(
//                                     fontSize: 11,
//                                     color: Colors.grey.shade500,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   route.to,
//                                   style: const TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                   textAlign: TextAlign.right,
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     const SizedBox(width: 10),

//                     // PRICE
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 12, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: Colors.teal.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Text(
//                         "TZS ${route.price}",
//                         style: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.teal,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),

//                 const SizedBox(height: 14),

//                 // ===== DIVIDER (ticket style) =====
//                 Row(
//                   children: List.generate(
//                     30,
//                     (index) => Expanded(
//                       child: Container(
//                         height: 1,
//                         color: index % 2 == 0
//                             ? Colors.grey.shade300
//                             : Colors.transparent,
//                       ),
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 14),

//                 // ===== BOTTOM ROW (DETAILS) =====
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     // TIME
//                     Row(
//                       children: [
//                         const Icon(Icons.access_time,
//                             size: 16, color: Colors.grey),
//                         const SizedBox(width: 6),
//                         Text(
//                           route.departureTime,
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),

//                     // BUS NAME
//                     Row(
//                       children: [
//                         const Icon(Icons.directions_bus,
//                             size: 16, color: Colors.grey),
//                         const SizedBox(width: 6),
//                         Text(
//                           route.busName,
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),

//                     // SELECTION INDICATOR
//                     if (isSelected)
//                       const Icon(Icons.check_circle,
//                           color: Colors.teal, size: 20),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     },
//   );
// }

  // ================= ROUTE LIST =================
  Widget _buildRouteList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];

        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                selectedRoute = route;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: From -> To with bus code
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.from,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              route.departureTime,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.teal,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              route.to,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.end,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "2:00 PM", // Assuming arrival time, you can add to route model if needed
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Bus details row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_bus, size: 16, color: Colors.teal),
                                const SizedBox(width: 6),
                                Text(
                                  route.busName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_seat, size: 16, color: Colors.orange),
                                const SizedBox(width: 6),
                                Text(
                                  "${route.seatsAvailable} seats left",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          "TZS ${route.price}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= TICKET VIEW =================
  Widget _buildTicketPreview() {
    final route = selectedRoute!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ticketCard(route),

          const SizedBox(height: 20),

          // ACTION BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.sms),
                label: const Text("Send SMS"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share),
                label: const Text("Share"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          TextButton(
            onPressed: () {
              setState(() {
                selectedRoute = null;
              });
            },
            child: const Text("← Back to routes"),
          )
        ],
      ),
    );
  }

  // ================= TICKET CARD =================
  Widget ticketCard(BusRoute route) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Text(
              "BUS TICKET",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // BODY
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ticketRow("Passenger", "John Doe"),
                _ticketRow("Bus", route.busName),
                _ticketRow("Route", "${route.from} → ${route.to}"),
                _ticketRow("Date", "12 Apr 2026"),
                _ticketRow("Time", route.departureTime),
                _ticketRow("Seat", "A1"),

                const Divider(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Amount",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      "TZS ${route.price}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // FOOTER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const Icon(Icons.qr_code, size: 60),
                const SizedBox(height: 8),
                Text(
                  "Ticket ID: ${DateTime.now().millisecondsSinceEpoch}",
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ================= MODEL =================
class BusRoute {
  final String from;
  final String to;
  final String departureTime;
  final String busName;
  final int price;
  final int seatsAvailable;

  BusRoute({
    required this.from,
    required this.to,
    required this.departureTime,
    required this.busName,
    required this.price,
    required this.seatsAvailable,
  });
}