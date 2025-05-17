import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'image': 'assets/onboarding1.png', // Replace with your asset paths
      'title': 'Welcome to Smart Waste',
      'desc': 'Manage your waste collection efficiently',
    },
    {
      'image': 'assets/onboarding2.png',
      'title': 'Track Collection Days',
      'desc': 'View your waste pickup schedule at a glance',
    },
    {
      'image': 'assets/onboarding3.png',
      'title': 'Set Your Location',
      'desc': 'Enable location services to get started',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Replace with Image.asset(slide['image']!)
                        Icon(
                          Icons.eco,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide['title']!,
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['desc']!,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 16,
                  ),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentPage == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child:
                  _currentPage == _slides.length - 1
                      ? ElevatedButton(
                        onPressed: widget.onFinish,
                        child: const Text('Get Started'),
                      )
                      : TextButton(
                        onPressed: () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Next'),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
