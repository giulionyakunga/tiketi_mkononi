import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> slides = [
    {
      "image": "assets/onboarding1.png",
      "title": "Welcome to Tiketi Mkononi",
      "desc": "Your ticket to the best events in town",
    },
    {
      "image": "assets/onboarding2.png",
      "title": "Easy Ticket Booking",
      "desc": "Book tickets for your favorite events in seconds",
    },
    {
      "image": "assets/onboarding1.jpg",
      "title": "Digital Tickets",
      "desc": "No more paper tickets - everything in your phone",
    },
  ];

  // Helper method to determine screen size
  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = _isLargeScreen(context);
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 1000 : double.infinity,
          ),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 40 : 20,
                        vertical: isLargeScreen ? 20 : 10,
                      ),
                      child: isLargeScreen
                          ? _buildHorizontalSlide(
                              context,
                              slides[index],
                              screenHeight,
                              screenWidth,
                            )
                          : _buildVerticalSlide(
                              context,
                              slides[index],
                              screenHeight,
                            ),
                    );
                  },
                ),
              ),
              _buildPageIndicator(),
              _buildNavigationButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalSlide(
    BuildContext context,
    Map<String, String> slide,
    double screenHeight,
    double screenWidth,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Image.asset(
            slide["image"]!,
            height: screenHeight * 0.5,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide["title"]!,
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                slide["desc"]!,
                style: TextStyle(
                  fontSize: screenWidth * 0.018,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalSlide(
    BuildContext context,
    Map<String, String> slide,
    double screenHeight,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          slide["image"]!,
          height: screenHeight * 0.4,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 30),
        Text(
          slide["title"]!,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.orange[800],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            slide["desc"]!,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          slides.length,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _currentPage == index
                  ? Colors.orange[800]
                  : Colors.grey[300],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(BuildContext context) {
    final bool isLargeScreen = _isLargeScreen(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 40 : 20,
        vertical: 20,
      ),
      child: SizedBox(
        width: isLargeScreen ? 400 : double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[800],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
          onPressed: () async {
            if (_currentPage < slides.length - 1) {
              _controller.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              );
            } else {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('first_launch', false);
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          child: Text(
            _currentPage == slides.length - 1 ? "Get Started" : "Next",
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}