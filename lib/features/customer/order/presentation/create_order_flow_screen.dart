import 'package:flutter/material.dart';
import '../models/order_draft_model.dart';
import 'steps/step1_address_screen.dart';
import 'steps/step2_package_screen.dart';
import 'steps/step3_confirm_pricing_screen.dart';

class CreateOrderFlowScreen extends StatefulWidget {
  final OrderVehicleType? initialVehicle;
  final OrderDraftModel? initialDraft;

  const CreateOrderFlowScreen({super.key, this.initialVehicle, this.initialDraft});

  @override
  State<CreateOrderFlowScreen> createState() => _CreateOrderFlowScreenState();
}

class _CreateOrderFlowScreenState extends State<CreateOrderFlowScreen> {
  final PageController _pageController = PageController();
  late OrderDraftModel _draft;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft ?? OrderDraftModel(
      vehicleType: widget.initialVehicle ?? OrderVehicleType.motorbike,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 0) {
          _prevPage();
        }
      },
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Step1AddressScreen(
            draft: _draft,
            onNext: _nextPage,
          ),
          Step2PackageScreen(
            draft: _draft,
            onNext: _nextPage,
            onBack: _prevPage,
          ),
          Step3ConfirmPricingScreen(
            draft: _draft,
            onBack: _prevPage,
            onOrderCompleted: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
