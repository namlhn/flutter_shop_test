import 'dart:async';
import 'package:eshop/Screen/Cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:intl/intl.dart';
import '../Helper/Color.dart';
import '../Helper/Session.dart';
import '../Helper/String.dart';
import '../Model/Model.dart';
import '../ui/widgets/PaymentRadio.dart';
import '../ui/widgets/SimBtn.dart';
import '../ui/widgets/SimpleAppBar.dart';

class Payment extends StatefulWidget {
  final Function update;
  final String? msg;

  const Payment(this.update, this.msg, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return StatePayment();
  }
}

List<Model> timeSlotList = [];
String? allowDay = "12";
bool codAllowed = true;
String? bankName, bankNo, acName, acNo, exDetails;

class StatePayment extends State<Payment> with TickerProviderStateMixin {
  bool _isLoading = true;
  String? startingDate;

  List<RadioModel> timeModel = [];
  List<RadioModel> payModel = [];
  List<RadioModel> timeModelList = [];
  List<String?> paymentMethodList = [];
  List<String> paymentIconList = [
    'assets/images/zafi.png',
    'assets/images/dollar.png',
    'assets/images/cod_payment.svg',
    'assets/images/paypal.svg',
    'assets/images/banktransfer.svg',

  ];

  Animation? buttonSqueezeanimation;
  AnimationController? buttonController;
  bool _isNetworkAvail = true;
  final plugin = PaystackPlugin();

  @override
  void initState() {
    super.initState();
    timeSlotList.length = 0;
    paymentMethodList = [
      'ZakumiFi Coin',
      'DIGITAL COIN',
      'COD',
      'PAYPAL',
      'BANK TRANSFER'
    ];
    for (int i = 0; i < paymentMethodList.length; i++) {
      payModel.add(RadioModel(
          isSelected: i == selectedMethod ? true : false,
          name: paymentMethodList[i],
          img: paymentIconList[i]));
    }
    buttonController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);
    buttonSqueezeanimation = Tween(
      begin: deviceWidth! * 0.7,
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: buttonController!,
      curve: const Interval(
        0.0,
        0.150,
      ),
    ));
  }

  @override
  void dispose() {
    buttonController!.dispose();
    super.dispose();
  }

  Future<void> _playAnimation() async {
    try {
      await buttonController!.forward();
    } on TickerCanceled {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getSimpleAppBar(
          getTranslated(context, 'PAYMENT_METHOD_LBL')!, context),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      elevation: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: paymentMethodList.length,
                              itemBuilder: (context, index) {
                                return paymentItem(index);
                              }),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            SimBtn(
              width: 0.8,
              height: 35,
              title: getTranslated(context, 'DONE'),
              onBtnSelected: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  dateCell(int index) {
    DateTime today = DateTime.parse(startingDate!);
    return InkWell(
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selectedDate == index ? colors.primary : null),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('EEE').format(today.add(Duration(days: index))),
              style: TextStyle(
                  color: selectedDate == index
                      ? Theme.of(context).colorScheme.white
                      : Theme.of(context).colorScheme.lightBlack2),
            ),
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: Text(
                DateFormat('dd').format(today.add(Duration(days: index))),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selectedDate == index
                        ? Theme.of(context).colorScheme.white
                        : Theme.of(context).colorScheme.lightBlack2),
              ),
            ),
            Text(
              DateFormat('MMM').format(today.add(Duration(days: index))),
              style: TextStyle(
                  color: selectedDate == index
                      ? Theme.of(context).colorScheme.white
                      : Theme.of(context).colorScheme.lightBlack2),
            ),
          ],
        ),
      ),
      onTap: () {
        DateTime date = today.add(Duration(days: index));

        if (mounted) selectedDate = index;
        selectedTime = null;
        selTime = null;
        selDate = DateFormat('yyyy-MM-dd').format(date);
        timeModel.clear();
        DateTime cur = DateTime.now();
        DateTime tdDate = DateTime(cur.year, cur.month, cur.day);
        if (date == tdDate) {
          if (timeSlotList.isNotEmpty) {
            for (int i = 0; i < timeSlotList.length; i++) {
              DateTime cur = DateTime.now();
              String time = timeSlotList[i].lastTime!;
              DateTime last = DateTime(
                  cur.year,
                  cur.month,
                  cur.day,
                  int.parse(time.split(':')[0]),
                  int.parse(time.split(':')[1]),
                  int.parse(time.split(':')[2]));

              if (cur.isBefore(last)) {
                timeModel.add(RadioModel(
                    isSelected: i == selectedTime ? true : false,
                    name: timeSlotList[i].name,
                    img: ''));
              }
            }
          }
        } else {
          if (timeSlotList.isNotEmpty) {
            for (int i = 0; i < timeSlotList.length; i++) {
              timeModel.add(RadioModel(
                  isSelected: i == selectedTime ? true : false,
                  name: timeSlotList[i].name,
                  img: ''));
            }
          }
        }
        setState(() {});
      },
    );
  }

  Widget timeSlotItem(int index) {
    return InkWell(
      onTap: () {
        if (mounted) {
          setState(() {
            selectedTime = index;
            selTime = timeModel[selectedTime!].name;

            for (var element in timeModel) {
              element.isSelected = false;
            }
            timeModel[index].isSelected = true;
            widget.update();
          });
        }
      },
      child: RadioItem(timeModel[index]),
    );
  }

  Widget paymentItem(int index) {
    return InkWell(
      onTap: () {
        if (mounted) {
          selectedMethod = index;
          payMethod = paymentMethodList[selectedMethod!];
          for (var element in payModel) {
            element.isSelected = false;
          }
          payModel[index].isSelected = true;
          widget.update();
          setState(() {

          });
        }
      },
      child: RadioItem(payModel[index]),
    );
  }
}
