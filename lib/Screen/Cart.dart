import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coinbase_commerce/coinbase.dart';
import 'package:coinbase_commerce/enums.dart';
import 'package:coinbase_commerce/returnObjects/checkoutObject.dart';
import 'package:eshop/Helper/Session.dart';
import 'package:eshop/Helper/SqliteData.dart';
import 'package:eshop/Provider/CartProvider.dart';
import 'package:eshop/Provider/UserProvider.dart';
import 'package:eshop/Screen/webview_custom.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_paypal_native/flutter_paypal_native.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_flutter_v2/apis/core/pairing/utils/pairing_models.dart';
import 'package:walletconnect_flutter_v2/apis/web3wallet/web3wallet.dart';
import 'package:flutter_paypal_native/str_helper.dart';
import 'package:flutter_paypal_native/models/environment.dart';
import 'package:flutter_paypal_native/models/currency_code.dart';
import 'package:flutter_paypal_native/models/purchase_unit.dart';
import 'package:flutter_paypal_native/models/user_action.dart';
import 'package:flutter_paypal_native/models/order_callback.dart';
import '../Helper/ApiBaseHelper.dart';
import '../Helper/Color.dart';
import '../Helper/String.dart';
import '../Model/Model.dart';
import '../Model/Section_Model.dart';
import '../Model/User.dart';
import '../ui/styles/DesignConfig.dart';
import '../ui/styles/Validators.dart';
import '../ui/widgets/AppBtn.dart';
import '../ui/widgets/DiscountLabel.dart';
import '../ui/widgets/SimBtn.dart';
import '../ui/widgets/SimpleAppBar.dart';
import 'Add_Address.dart';
import 'HomePage.dart';
import 'Manage_Address.dart';
import 'Order_Success.dart';
import 'Payment.dart';
import 'PaypalWebviewActivity.dart';

class Cart extends StatefulWidget {
  final bool fromBottom;

  const Cart({Key? key, required this.fromBottom}) : super(key: key);

  @override
  State<StatefulWidget> createState() => StateCart();
}

List<User> addressList = [
  User(name: "Nhà Nam", address: "2/4/64A Lê Thúc Hoạch", cityId: "1")
];
List<Promo> promoList = [];

double totalPrice = 0, oriPrice = 0, delCharge = 0, taxPer = 0;

int? selectedAddress = 0;

String? selAddress, payMethod = 'ZakumiFi Coin', selTime, selDate, promocode;
bool? isTimeSlot,
    isPromoValid = false,
    isUseWallet = false,
    isPayLayShow = true;

int? selectedTime, selectedDate, selectedMethod;
bool isPromoLen = false;

double promoAmt = 0;
double remWalBal = 0, usedBal = 0;
List<File> prescriptionImages = [];

String isStorePickUp = "false";
double codDeliverChargesOfShipRocket = 0.0,
    prePaidDeliverChargesOfShipRocket = 0.0;
bool? isLocalDelCharge;

String shipRocketDeliverableDate = '';

class StateCart extends State<Cart> with TickerProviderStateMixin {
  List<Model> deliverableList = [];
  bool _isCartLoad = true, _placeOrder = true, _isSaveLoad = true;

  Animation? buttonSqueezeanimation;
  AnimationController? buttonController;
  bool _isNetworkAvail = true;
  TextEditingController promoC = TextEditingController();
  final List<TextEditingController> _controller = [];

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  String? msg;
  bool _isLoading = true;

  //Razorpay? _razorpay;
  final _FlutterPaypalNativePlugin = FlutterPaypalNative.instance;

  TextEditingController noteC = TextEditingController();
  StateSetter? checkoutState;
  final paystackPlugin = PaystackPlugin();
  bool deliverable = false;
  bool saveLater = false, addCart = false;
  final ScrollController _scrollControllerOnCartItems = ScrollController();
  final ScrollController _scrollControllerOnSaveForLaterItems =
      ScrollController();
  TextEditingController emailController = TextEditingController();
  List<String> proIds = [];
  List<String> proVarIds = [];
  var db = DatabaseHelper();
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();

  bool isAvailable = true;
  bool confDia = true;

  //rozarpay
  String razorpayOrderId = '';
  String? rozorpayMsg;

  @override
  void initState() {
    super.initState();
    prescriptionImages.clear();
    callApi();
    initPayPal();
    addressList = [
      User(name: "Nhà Nam", address: "2/4/64A Lê Thúc Hoạch", cityId: "1")
    ];
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

  void initPayPal() async {
    //set debugMode for error logging
    FlutterPaypalNative.isDebugMode = true;

    //initiate payPal plugin
    await _FlutterPaypalNativePlugin.init(
      //your app id !!! No Underscore!!! see readme.md for help
      returnUrl: "com.wrteam.eshop://paypalpay",
      //client id from developer dashboard
      clientID: "AaFTXzhM7h8XgEr9yKkGqdi42SqVKaosxHcTMqKz_GdEME-1xme4iJmR-UxBEgBl-VyiI-iZgBb--S9_",
      //sandbox, staging, live etc
      payPalEnvironment: FPayPalEnvironment.sandbox,

      //what currency do you plan to use? default is US dollars
      currencyCode: FPayPalCurrencyCode.usd,
      //action paynow?
      action: FPayPalUserAction.payNow,
    );

    //call backs for payment
    _FlutterPaypalNativePlugin.setPayPalOrderCallback(
      callback: FPayPalOrderCallback(
        onCancel: () {
          //user canceled the payment
          setSnackbar('cancel', context);
        },
        onSuccess: (data) {
          //successfully paid
          //remove all items from queue
          _FlutterPaypalNativePlugin.removeAllPurchaseItems();
          String orderID = data.orderId ?? "";
          placeOrder('');
        },
        onError: (data) {
          //an error occured
          setSnackbar("error: ${data.reason}", context);
        },
        onShippingChange: (data) {
          //the user updated the shipping address
          setSnackbar(
              "shipping change: ${data.shippingAddress?.addressLine1 ?? ""}",
              context);
        },
      ),
    );
  }

  callApi() async {
    proIds = (await db.getCart())!;
    _getOffCart();
  }

  clearAll() async {
    totalPrice = 0;
    oriPrice = 0;

    taxPer = 0;
    delCharge = 0;
    //addressList.clear();
    List<SectionModel> cartList = context.read<CartProvider>().cartList;
    while (cartList.isNotEmpty) {
      db.removeCart(cartList[0].productList![0].prVarientList![0].id!,
          cartList[0].id!, context);
      cartList.removeWhere((item) => item.varientId == cartList[0].varientId);
      proIds = (await db.getCart())!;

      setState(() {});
    }
  }

  @override
  void dispose() {
    //  buttonController!.dispose();
    //  promoC.dispose();
    //  emailController.dispose();
    //  _scrollControllerOnCartItems.removeListener(() {});
    //  _scrollControllerOnSaveForLaterItems.removeListener(() {});
/*
    for (int i = 0; i < _controller.length; i++) {
      _controller[i].dispose();
    }*/

    //  if (_razorpay != null) _razorpay!.clear();
    super.dispose();
  }

  Future<void> _playAnimation() async {
    try {
      await buttonController!.forward();
    } on TickerCanceled {}
  }

  Widget noInternet(BuildContext context) {
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        noIntImage(),
        noIntText(context),
        noIntDec(context),
        AppBtn(
          title: getTranslated(context, 'TRY_AGAIN_INT_LBL'),
          btnAnim: buttonSqueezeanimation,
          btnCntrl: buttonController,
          onBtnSelected: () async {
            _playAnimation();

            Future.delayed(const Duration(seconds: 2)).then((_) async {
              _isNetworkAvail = await isNetworkAvailable();
              if (_isNetworkAvail) {
                Navigator.pushReplacement(
                    context,
                    CupertinoPageRoute(
                        builder: (BuildContext context) => super.widget));
              } else {
                await buttonController!.reverse();
                if (mounted) setState(() {});
              }
            });
          },
        )
      ]),
    );
  }

  updatePromo(String promo) {
    setState(() {
      isPromoLen = false;
      promoC.text = promo;
    });
  }

  @override
  Widget build(BuildContext context) {
    deviceHeight = MediaQuery.of(context).size.height;
    deviceWidth = MediaQuery.of(context).size.width;
    hideAppbarAndBottomBarOnScroll(_scrollControllerOnCartItems, context);
    hideAppbarAndBottomBarOnScroll(
        _scrollControllerOnSaveForLaterItems, context);
    return Scaffold(
        appBar: widget.fromBottom
            ? null
            : getSimpleAppBar(getTranslated(context, 'CART')!, context),
        body: Stack(
          children: <Widget>[
            _showContent(context),
            /*
            Selector<CartProvider, bool>(
              builder: (context, data, child) {
                return showCircularProgress(data, colors.primary);
              },
              selector: (_, provider) => provider.isProgress,
            ),*/
          ],
        ));
  }

  addAndRemoveQty(
      String qty,
      int from,
      int totalLen,
      int index,
      double price,
      int selectedPos,
      double total,
      List<SectionModel> cartList,
      int itemCounter) async {
    if (from == 1) {
      if (int.parse(qty) >= totalLen) {
        setSnackbar("${getTranslated(context, 'MAXQTY')!}  $qty", context);
      } else {
        db.updateCart(
            cartList[index].id!,
            cartList[index].productList![0].prVarientList![selectedPos].id!,
            (int.parse(qty) + itemCounter).toString());
        context.read<CartProvider>().updateCartItem(
            cartList[index].productList![0].id!,
            (int.parse(qty) + itemCounter).toString(),
            selectedPos,
            cartList[index].productList![0].prVarientList![selectedPos].id!);

        oriPrice = (oriPrice + price);

        setState(() {});
      }
    } else if (from == 2) {
      if (int.parse(qty) <= cartList[index].productList![0].minOrderQuntity!) {
        db.updateCart(
            cartList[index].id!,
            cartList[index].productList![0].prVarientList![selectedPos].id!,
            itemCounter.toString());
        context.read<CartProvider>().updateCartItem(
            cartList[index].productList![0].id!,
            itemCounter.toString(),
            selectedPos,
            cartList[index].productList![0].prVarientList![selectedPos].id!);
        setState(() {});
      } else {
        db.updateCart(
            cartList[index].id!,
            cartList[index].productList![0].prVarientList![selectedPos].id!,
            (int.parse(qty) - itemCounter).toString());
        context.read<CartProvider>().updateCartItem(
            cartList[index].productList![0].id!,
            (int.parse(qty) - itemCounter).toString(),
            selectedPos,
            cartList[index].productList![0].prVarientList![selectedPos].id!);
        oriPrice = (oriPrice - price);
        setState(() {});
      }
    } else {
      db.updateCart(cartList[index].id!,
          cartList[index].productList![0].prVarientList![selectedPos].id!, qty);
      context.read<CartProvider>().updateCartItem(
          cartList[index].productList![0].id!,
          qty,
          selectedPos,
          cartList[index].productList![0].prVarientList![selectedPos].id!);
      oriPrice = (oriPrice - total + (int.parse(qty) * price));

      setState(() {});
    }
  }

  Widget listItem(int index, List<SectionModel> cartList) {
    int selectedPos = 0;
    for (int i = 0;
        i < cartList[index].productList![0].prVarientList!.length;
        i++) {
      if (cartList[index].varientId ==
          cartList[index].productList![0].prVarientList![i].id) selectedPos = i;
    }
    String? offPer;

    double price = double.parse(
        cartList[index].productList![0].prVarientList![selectedPos].disPrice!);
    if (price == 0) {
      price = double.parse(
          cartList[index].productList![0].prVarientList![selectedPos].price!);
    } else {
      double off = (double.parse(cartList[index]
              .productList![0]
              .prVarientList![selectedPos]
              .price!)) -
          price;
      offPer = (off *
              100 /
              double.parse(cartList[index]
                  .productList![0]
                  .prVarientList![selectedPos]
                  .price!))
          .toStringAsFixed(2);
    }

    cartList[index].perItemPrice = price.toString();

    if (_controller.length < index + 1) {
      _controller.add(TextEditingController());
    }
    if (cartList[index].productList![0].availability != "0") {
      cartList[index].perItemTotal =
          ((cartList[index].productList![0].isSalesOn == "1"
                      ? double.parse(cartList[index]
                          .productList![0]
                          .prVarientList![selectedPos]
                          .saleFinalPrice!)
                      : price) *
                  double.parse(cartList[index].qty!))
              .toString();
      _controller[index].text = cartList[index].qty!;
    }
    List att = [], val = [];
    if (cartList[index].productList![0].prVarientList![selectedPos].attr_name !=
        "") {
      att = cartList[index]
          .productList![0]
          .prVarientList![selectedPos]
          .attr_name!
          .split(',');
      val = cartList[index]
          .productList![0]
          .prVarientList![selectedPos]
          .varient_value!
          .split(',');
    }

    if (cartList[index].productList![0].attributeList!.isEmpty) {
      if (cartList[index].productList![0].availability == "0") {
        isAvailable = false;
      }
    } else {
      if (cartList[index]
              .productList![0]
              .prVarientList![selectedPos]
              .availability ==
          "0") {
        isAvailable = false;
      }
    }

    double total = ((cartList[index].productList![0].isSalesOn == "1"
            ? double.parse(cartList[index]
                .productList![0]
                .prVarientList![selectedPos]
                .saleFinalPrice!)
            : price) *
        double.parse(cartList[index]
            .productList![0]
            .prVarientList![selectedPos]
            .cartCount!));
    return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 1.0,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              elevation: 0.1,
              child: Row(
                children: <Widget>[
                  Hero(
                      tag:
                          "$cartHero$index${cartList[index].productList![0].id}",
                      child: Stack(
                        children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(7.0),
                              child: Stack(children: [
                                networkImageCommon(
                                    cartList[index].productList![0].type ==
                                                "variable_product" &&
                                            cartList[index]
                                                .productList![0]
                                                .prVarientList![selectedPos]
                                                .images!
                                                .isNotEmpty
                                        ? cartList[index]
                                            .productList![0]
                                            .prVarientList![selectedPos]
                                            .images![0]
                                        : cartList[index]
                                            .productList![0]
                                            .image!,
                                    100,
                                    false,
                                    height: 100,
                                    width: 100),
                                /*CachedNetworkImage(
                                    imageUrl:
                                        cartList[index].productList![0].type ==
                                                    "variable_product" &&
                                                cartList[index]
                                                    .productList![0]
                                                    .prVarientList![selectedPos]
                                                    .images!
                                                    .isNotEmpty
                                            ? cartList[index]
                                                .productList![0]
                                                .prVarientList![selectedPos]
                                                .images![0]
                                            : cartList[index]
                                                .productList![0]
                                                .image!,
                                    height: 100.0,
                                    width: 100.0,
                                    fit: extendImg
                                        ? BoxFit.fill
                                        : BoxFit.contain,
                                    errorWidget: (context, error, stackTrace) =>
                                        erroWidget(125),
                                    placeholder: (context, url) {
                                      return placeHolder(125);
                                    })*/
                                Positioned.fill(
                                    child: cartList[index]
                                                .productList![0]
                                                .prVarientList![selectedPos]
                                                .availability ==
                                            "0"
                                        ? Container(
                                            height: 55,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .white70,
                                            padding: const EdgeInsets.all(2),
                                            child: Center(
                                              child: Text(
                                                getTranslated(context,
                                                    'OUT_OF_STOCK_LBL')!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall!
                                                    .copyWith(
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          )
                                        : Container()),
                              ])),
                          offPer != null
                              ? getDiscountLabel(
                                  cartList[index].productList![0].isSalesOn ==
                                          "1"
                                      ? double.parse(cartList[index]
                                              .productList![0]
                                              .saleDis!)
                                          .toStringAsFixed(2)
                                      : offPer)
                              : Container()
                        ],
                      )),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      top: 5.0),
                                  child: Text(
                                    cartList[index].productList![0].name!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .fontColor,
                                            fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              InkWell(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      start: 8.0, end: 8, bottom: 8),
                                  child: Icon(
                                    Icons.close,
                                    size: 20,
                                    color:
                                        Theme.of(context).colorScheme.fontColor,
                                  ),
                                ),
                                onTap: () async {
                                  if (context.read<CartProvider>().isProgress ==
                                      false) {
                                    db.removeCart(
                                        cartList[index]
                                            .productList![0]
                                            .prVarientList![selectedPos]
                                            .id!,
                                        cartList[index].id!,
                                        context);
                                    cartList.removeWhere((item) =>
                                        item.varientId ==
                                        cartList[index].varientId);
                                    oriPrice = oriPrice - total;
                                    proIds = (await db.getCart())!;

                                    setState(() {});
                                  }
                                },
                              )
                            ],
                          ),
                          cartList[index]
                                          .productList![0]
                                          .prVarientList![selectedPos]
                                          .attr_name !=
                                      null &&
                                  cartList[index]
                                      .productList![0]
                                      .prVarientList![selectedPos]
                                      .attr_name!
                                      .isNotEmpty
                              ? ListView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: att.length,
                                  itemBuilder: (context, index) {
                                    return Row(children: [
                                      Flexible(
                                        child: Text(
                                          att[index].trim() + ":",
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall!
                                              .copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .lightBlack,
                                              ),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                                start: 5.0),
                                        child: Text(
                                          val[index],
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .lightBlack,
                                                  fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    ]);
                                  })
                              : const SizedBox(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                double.parse(cartList[index]
                                            .productList![0]
                                            .prVarientList![selectedPos]
                                            .disPrice!) !=
                                        0
                                    ? getPriceFormat(
                                        context,
                                        double.parse(cartList[index]
                                            .productList![0]
                                            .prVarientList![selectedPos]
                                            .price!))!
                                    : "",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall!
                                    .copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        letterSpacing: 0.7),
                              ),
                              Text(
                                cartList[index].productList![0].isSalesOn == "1"
                                    ? getPriceFormat(
                                        context,
                                        double.parse(cartList[index]
                                            .productList![0]
                                            .prVarientList![selectedPos]
                                            .saleFinalPrice!))!
                                    : ' ${getPriceFormat(context, price)!} ',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.fontColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                          cartList[index].productList![0].availability == "1" ||
                                  cartList[index].productList![0].stockType ==
                                      ""
                              ? Row(
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        InkWell(
                                          child: Card(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Icon(
                                                Icons.remove,
                                                size: 15,
                                              ),
                                            ),
                                          ),
                                          onTap: () {
                                            if (context
                                                    .read<CartProvider>()
                                                    .isProgress ==
                                                false) {
                                              if (CUR_USERID != null) {
                                                removeFromCart(
                                                    index,
                                                    false,
                                                    cartList,
                                                    false,
                                                    selectedPos);
                                              } else {
                                                if ((int.parse(cartList[index]
                                                        .productList![0]
                                                        .prVarientList![
                                                            selectedPos]
                                                        .cartCount!)) >
                                                    1) {
                                                  setState(() {
                                                    addAndRemoveQty(
                                                        cartList[index]
                                                            .productList![0]
                                                            .prVarientList![
                                                                selectedPos]
                                                            .cartCount!,
                                                        2,
                                                        cartList[index]
                                                                .productList![0]
                                                                .itemsCounter!
                                                                .length *
                                                            int.parse(cartList[
                                                                    index]
                                                                .productList![0]
                                                                .qtyStepSize!),
                                                        index,
                                                        cartList[index]
                                                                    .productList![
                                                                        0]
                                                                    .isSalesOn ==
                                                                "1"
                                                            ? double.parse(cartList[
                                                                    index]
                                                                .productList![0]
                                                                .prVarientList![
                                                                    selectedPos]
                                                                .saleFinalPrice!)
                                                            : price,
                                                        selectedPos,
                                                        total,
                                                        cartList,
                                                        int.parse(
                                                            cartList[index]
                                                                .productList![0]
                                                                .qtyStepSize!));
                                                  });
                                                }
                                              }
                                            }
                                          },
                                        ),
                                        SizedBox(
                                          width: 37,
                                          height: 20,
                                          child: Stack(
                                            children: [
                                              TextField(
                                                textAlign: TextAlign.center,
                                                readOnly: true,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .fontColor),
                                                controller: _controller[index],
                                                decoration:
                                                    const InputDecoration(
                                                  border: InputBorder.none,
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                tooltip: '',
                                                icon: const Icon(
                                                  Icons.arrow_drop_down,
                                                  size: 1,
                                                ),
                                                onSelected: (String value) {
                                                  if (context
                                                          .read<CartProvider>()
                                                          .isProgress ==
                                                      false) {
                                                    if (CUR_USERID != null) {
                                                      addToCart(index, value,
                                                          cartList);
                                                    } else {
                                                      addAndRemoveQty(
                                                          value,
                                                          3,
                                                          cartList[index]
                                                                  .productList![
                                                                      0]
                                                                  .itemsCounter!
                                                                  .length *
                                                              int.parse(cartList[
                                                                      index]
                                                                  .productList![
                                                                      0]
                                                                  .qtyStepSize!),
                                                          index,
                                                          cartList[index]
                                                                      .productList![
                                                                          0]
                                                                      .isSalesOn ==
                                                                  "1"
                                                              ? double.parse(cartList[
                                                                      index]
                                                                  .productList![
                                                                      0]
                                                                  .prVarientList![
                                                                      selectedPos]
                                                                  .saleFinalPrice!)
                                                              : price,
                                                          selectedPos,
                                                          total,
                                                          cartList,
                                                          int.parse(cartList[
                                                                  index]
                                                              .productList![0]
                                                              .qtyStepSize!));
                                                    }
                                                  }
                                                },
                                                itemBuilder:
                                                    (BuildContext context) {
                                                  return cartList[index]
                                                      .productList![0]
                                                      .itemsCounter!
                                                      .map<
                                                              PopupMenuItem<
                                                                  String>>(
                                                          (String value) {
                                                    return PopupMenuItem(
                                                        value: value,
                                                        child: Text(value,
                                                            style: TextStyle(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .fontColor)));
                                                  }).toList();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          child: Card(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Icon(
                                                Icons.add,
                                                size: 15,
                                              ),
                                            ),
                                          ),
                                          onTap: () {
                                            if (context
                                                    .read<CartProvider>()
                                                    .isProgress ==
                                                false) {
                                              if (CUR_USERID != null) {
                                                addToCart(
                                                    index,
                                                    (int.parse(cartList[index]
                                                                .qty!) +
                                                            int.parse(cartList[
                                                                    index]
                                                                .productList![0]
                                                                .qtyStepSize!))
                                                        .toString(),
                                                    cartList);
                                              } else {
                                                addAndRemoveQty(
                                                    cartList[index]
                                                        .productList![0]
                                                        .prVarientList![
                                                            selectedPos]
                                                        .cartCount!,
                                                    1,
                                                    cartList[index]
                                                            .productList![0]
                                                            .itemsCounter!
                                                            .length *
                                                        int.parse(
                                                            cartList[index]
                                                                .productList![0]
                                                                .qtyStepSize!),
                                                    index,
                                                    cartList[index]
                                                                .productList![0]
                                                                .isSalesOn ==
                                                            "1"
                                                        ? double.parse(cartList[
                                                                index]
                                                            .productList![0]
                                                            .prVarientList![
                                                                selectedPos]
                                                            .saleFinalPrice!)
                                                        : price,
                                                    selectedPos,
                                                    total,
                                                    cartList,
                                                    int.parse(cartList[index]
                                                        .productList![0]
                                                        .qtyStepSize!));
                                              }
                                            }
                                          },
                                        )
                                      ],
                                    ),
                                  ],
                                )
                              : Container(),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ));
  }

  Widget cartItem(int index, List<SectionModel> cartList) {
    int selectedPos = 0;
    for (int i = 0;
        i < cartList[index].productList![0].prVarientList!.length;
        i++) {
      if (cartList[index].varientId ==
          cartList[index].productList![0].prVarientList![i].id) selectedPos = i;
    }

    double price = double.parse(
        cartList[index].productList![0].prVarientList![selectedPos].disPrice!);
    if (price == 0) {
      price = double.parse(
          cartList[index].productList![0].prVarientList![selectedPos].price!);
    }

    cartList[index].perItemPrice = price.toString();
    cartList[index].perItemTotal =
        ((cartList[index].productList![0].isSalesOn == "1"
                    ? double.parse(cartList[index]
                        .productList![0]
                        .prVarientList![selectedPos]
                        .saleFinalPrice!)
                    : price) *
                double.parse(cartList[index].qty!))
            .toString();

    _controller[index].text = cartList[index].qty!;

    List att = [], val = [];
    if (cartList[index].productList![0].prVarientList![selectedPos].attr_name !=
        "") {
      att = cartList[index]
          .productList![0]
          .prVarientList![selectedPos]
          .attr_name!
          .split(',');
      val = cartList[index]
          .productList![0]
          .prVarientList![selectedPos]
          .varient_value!
          .split(',');
    }

    String? id, varId;
    bool? avail = false;
    String deliveryMsg = '';
    if (deliverableList.isNotEmpty) {
      id = cartList[index].id;
      varId = cartList[index].productList![0].prVarientList![selectedPos].id;

      for (int i = 0; i < deliverableList.length; i++) {
        if (id == deliverableList[i].prodId &&
            varId == deliverableList[i].varId) {
          avail = deliverableList[i].isDel;
          if (deliverableList[i].msg != null) {
            deliveryMsg = deliverableList[i].msg!;
          }

          break;
        }
      }
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(7.0),
                  child: networkImageCommon(
                      cartList[index].productList![0].type ==
                                  "variable_product" &&
                              cartList[index]
                                  .productList![0]
                                  .prVarientList![selectedPos]
                                  .images!
                                  .isNotEmpty
                          ? cartList[index]
                              .productList![0]
                              .prVarientList![selectedPos]
                              .images![0]
                          : cartList[index].productList![0].image!,
                      100,
                      false,
                      height: 100,
                      width: 100),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(top: 5.0),
                                child: Text(
                                  cartList[index].productList![0].name!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .lightBlack),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            InkWell(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                    start: 8.0, end: 8, bottom: 8),
                                child: Icon(
                                  Icons.close,
                                  size: 13,
                                  color:
                                      Theme.of(context).colorScheme.fontColor,
                                ),
                              ),
                              onTap: () {
                                if (context.read<CartProvider>().isProgress ==
                                    false) {
                                  deleteProductFromCart(
                                      index, 1, cartList, selectedPos);
                                  // removeFromCartCheckout(index, true, cartList);
                                }
                              },
                            )
                          ],
                        ),
                        cartList[index]
                                        .productList![0]
                                        .prVarientList![selectedPos]
                                        .attr_name !=
                                    "" &&
                                cartList[index]
                                    .productList![0]
                                    .prVarientList![selectedPos]
                                    .attr_name!
                                    .isNotEmpty
                            ? ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: att.length,
                                itemBuilder: (context, index) {
                                  return Row(children: [
                                    Flexible(
                                      child: Text(
                                        att[index].trim() + ":",
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .lightBlack,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                          start: 5.0),
                                      child: Text(
                                        val[index],
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .lightBlack,
                                                fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  ]);
                                })
                            : Container(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      double.parse(cartList[index]
                                                  .productList![0]
                                                  .prVarientList![selectedPos]
                                                  .disPrice!) !=
                                              0
                                          ? getPriceFormat(
                                              context,
                                              double.parse(cartList[index]
                                                  .productList![0]
                                                  .prVarientList![selectedPos]
                                                  .price!))!
                                          : "",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall!
                                          .copyWith(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              letterSpacing: 0.7),
                                    ),
                                  ),
                                  Text(
                                    cartList[index].productList![0].isSalesOn ==
                                            "1"
                                        ? getPriceFormat(
                                            context,
                                            double.parse(cartList[index]
                                                .productList![0]
                                                .prVarientList![selectedPos]
                                                .saleFinalPrice!))!
                                        : '${getPriceFormat(context, price)!} ',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .fontColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            cartList[index].productList![0].availability ==
                                        "1" ||
                                    cartList[index].productList![0].stockType ==
                                        ""
                                ? Row(
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          InkWell(
                                            child: Card(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Icon(
                                                  Icons.remove,
                                                  size: 15,
                                                ),
                                              ),
                                            ),
                                            onTap: () {
                                              if (context
                                                      .read<CartProvider>()
                                                      .isProgress ==
                                                  false) {
                                                removeFromCartCheckout(
                                                    index, false, cartList);
                                              }
                                            },
                                          ),
                                          SizedBox(
                                            width: 37,
                                            height: 20,
                                            child: Stack(
                                              children: [
                                                TextField(
                                                  textAlign: TextAlign.center,
                                                  readOnly: true,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .fontColor),
                                                  controller:
                                                      _controller[index],
                                                  decoration:
                                                      const InputDecoration(
                                                    border: InputBorder.none,
                                                  ),
                                                ),
                                                PopupMenuButton<String>(
                                                  tooltip: '',
                                                  icon: const Icon(
                                                    Icons.arrow_drop_down,
                                                    size: 1,
                                                  ),
                                                  onSelected: (String value) {
                                                    addToCartCheckout(
                                                        index, value, cartList);
                                                  },
                                                  itemBuilder:
                                                      (BuildContext context) {
                                                    return cartList[index]
                                                        .productList![0]
                                                        .itemsCounter!
                                                        .map<
                                                                PopupMenuItem<
                                                                    String>>(
                                                            (String value) {
                                                      return PopupMenuItem(
                                                          value: value,
                                                          child: Text(
                                                            value,
                                                            style: TextStyle(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .fontColor),
                                                          ));
                                                    }).toList();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          InkWell(
                                              child: Card(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                ),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Icon(
                                                    Icons.add,
                                                    size: 15,
                                                  ),
                                                ),
                                              ),
                                              onTap: () {
                                                if (context
                                                        .read<CartProvider>()
                                                        .isProgress ==
                                                    false) {
                                                  addToCartCheckout(
                                                      index,
                                                      (int.parse(cartList[index]
                                                                  .qty!) +
                                                              int.parse(cartList[
                                                                      index]
                                                                  .productList![
                                                                      0]
                                                                  .qtyStepSize!))
                                                          .toString(),
                                                      cartList);
                                                }
                                              })
                                        ],
                                      ),
                                    ],
                                  )
                                : Container(),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getOffCart() async {
    final String response =
        await rootBundle.loadString('assets/data/products.json');
    final getdata = await json.decode(response);
    var data = getdata["data"];
    setState(() {
      context.read<CartProvider>().setCartlist([]);
      oriPrice = 0;
    });

    List<Product> cartList =
        (data as List).map((data) => Product.fromJson(data)).toList();

    for (int i = 0; i < cartList.length; i++) {
      for (int j = 0; j < cartList[i].prVarientList!.length; j++) {
        if (proIds.contains(cartList[i].prVarientList![j].id)) {
          String qty = (await db.checkCartItemExists(
              cartList[i].id!, cartList[i].prVarientList![j].id!))!;

          List<Product>? prList = [];
          cartList[i].prVarientList![j].cartCount = qty;
          prList.add(cartList[i]);

          context.read<CartProvider>().addCartItem(SectionModel(
                id: cartList[i].id,
                varientId: cartList[i].prVarientList![j].id,
                qty: qty,
                productList: prList,
              ));

          double price = double.parse(cartList[i].prVarientList![j].disPrice!);
          if (price == 0) {
            price = double.parse(cartList[i].prVarientList![j].price!);
          }

          double total = (price * int.parse(qty));
          setState(() {
            oriPrice = oriPrice + total;
          });
        }
      }
    }
    if (mounted) {
      setState(() {
        _isCartLoad = false;
      });
    }
  }

  Future<void> addToCart(
      int index, String qty, List<SectionModel> cartList) async {
    _isNetworkAvail = await isNetworkAvailable();

    if (_isNetworkAvail) {
      try {
        context.read<CartProvider>().setProgress(true);

        if (int.parse(qty) < cartList[index].productList![0].minOrderQuntity!) {
          qty = cartList[index].productList![0].minOrderQuntity.toString();

          setSnackbar("${getTranslated(context, 'MIN_MSG')}$qty", context);
        }

        var parameter = {
          PRODUCT_VARIENT_ID: cartList[index].varientId,
          USER_ID: CUR_USERID,
          QTY: qty,
        };
        apiBaseHelper.postAPICall(manageCartApi, parameter).then((getdata) {
          bool error = getdata["error"];
          String? msg = getdata["message"];
          if (!error) {
            var data = getdata["data"];

            String qty = data['total_quantity'];

            context.read<UserProvider>().setCartCount(data['cart_count']);
            cartList[index].qty = qty;

            oriPrice = double.parse(data['sub_total']);

            _controller[index].text = qty;
            totalPrice = 0;

            var cart = getdata["cart"];
            List<SectionModel> uptcartList = (cart as List)
                .map((cart) => SectionModel.fromCart(cart))
                .toList();
            context.read<CartProvider>().setCartlist(uptcartList);

            totalPrice = oriPrice;

            setState(() {});
            context.read<CartProvider>().setProgress(false);
          } else {
            setSnackbar(msg!, context);
            context.read<CartProvider>().setProgress(false);
          }
        }, onError: (error) {
          setSnackbar(error.toString(), context);
        });
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
        context.read<CartProvider>().setProgress(false);
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  Future<void> addToCartCheckout(
      int index, String qty, List<SectionModel> cartList) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        context.read<CartProvider>().setProgress(true);

        if (int.parse(qty) < cartList[index].productList![0].minOrderQuntity!) {
          qty = cartList[index].productList![0].minOrderQuntity.toString();

          setSnackbar("${getTranslated(context, 'MIN_MSG')}$qty", context);
        }

        var parameter = {
          PRODUCT_VARIENT_ID: cartList[index].varientId,
          USER_ID: CUR_USERID,
          QTY: qty,
        };
        apiBaseHelper.postAPICall(manageCartApi, parameter).then((getdata) {
          bool error = getdata["error"];
          String? msg = getdata["message"];
          if (!error) {
            var data = getdata["data"];

            String qty = data['total_quantity'];

            context.read<UserProvider>().setCartCount(data['cart_count']);
            cartList[index].qty = qty;

            oriPrice = double.parse(data['sub_total']);
            _controller[index].text = qty;
            totalPrice = 0;

            if (IS_SHIPROCKET_ON == "0") {
              if (!ISFLAT_DEL) {
                if ((oriPrice) <
                    double.parse(addressList[selectedAddress!].freeAmt!)) {
                  delCharge = double.parse(
                      addressList[selectedAddress!].deliveryCharge!);
                } else {
                  delCharge = 0;
                }
              } else {
                if ((oriPrice) < double.parse(MIN_AMT!)) {
                  delCharge = double.parse(CUR_DEL_CHR!);
                } else {
                  delCharge = 0;
                }
              }
            }

            totalPrice = oriPrice;

            if (isPromoValid!) {
            } else if (isUseWallet!) {
              if (mounted) {
                checkoutState!(() {
                  remWalBal = 0;
                  usedBal = 0;
                  isUseWallet = false;
                  isPayLayShow = true;

                  selectedMethod = null;
                });
              }
              setState(() {});
            } else {
              context.read<CartProvider>().setProgress(false);
              setState(() {});
              checkoutState!(() {});
            }
          } else {
            setSnackbar(msg!, context);
            context.read<CartProvider>().setProgress(false);
          }
        }, onError: (error) {
          setSnackbar(error.toString(), context);
        });
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
        context.read<CartProvider>().setProgress(false);
      }
    } else {
      if (mounted) {
        checkoutState!(() {
          _isNetworkAvail = false;
        });
      }
      setState(() {});
    }
  }

  removeFromCartCheckout(
      int index, bool remove, List<SectionModel> cartList) async {
    _isNetworkAvail = await isNetworkAvailable();

    if (!remove &&
        int.parse(cartList[index].qty!) ==
            cartList[index].productList![0].minOrderQuntity) {
      setSnackbar("${getTranslated(context, 'MIN_MSG')}${cartList[index].qty}",
          context);
    } else {
      if (_isNetworkAvail) {
        try {
          context.read<CartProvider>().setProgress(true);

          int? qty;
          if (remove) {
            qty = 0;
          } else {
            qty = (int.parse(cartList[index].qty!) -
                int.parse(cartList[index].productList![0].qtyStepSize!));

            if (qty < cartList[index].productList![0].minOrderQuntity!) {
              qty = cartList[index].productList![0].minOrderQuntity;

              setSnackbar("${getTranslated(context, 'MIN_MSG')}$qty", context);
            }
          }

          var parameter = {
            PRODUCT_VARIENT_ID: cartList[index].varientId,
            USER_ID: CUR_USERID,
            QTY: qty.toString()
          };
          apiBaseHelper.postAPICall(manageCartApi, parameter).then((getdata) {
            bool error = getdata["error"];
            String? msg = getdata["message"];
            if (!error) {
              var data = getdata["data"];

              String? qty = data['total_quantity'];

              context.read<UserProvider>().setCartCount(data['cart_count']);
              if (qty == "0") remove = true;

              if (remove) {
                context
                    .read<CartProvider>()
                    .removeCartItem(cartList[index].varientId!);
              } else {
                cartList[index].qty = qty.toString();
              }

              oriPrice = double.parse(data[SUB_TOTAL]);
              if (IS_SHIPROCKET_ON == "0") {
                if (!ISFLAT_DEL) {
                  if ((oriPrice) <
                      double.parse(addressList[selectedAddress!].freeAmt!)) {
                    delCharge = double.parse(
                        addressList[selectedAddress!].deliveryCharge!);
                  } else {
                    delCharge = 0;
                  }
                } else {
                  if ((oriPrice) < double.parse(MIN_AMT!)) {
                    delCharge = double.parse(CUR_DEL_CHR!);
                  } else {
                    delCharge = 0;
                  }
                }
              }

              totalPrice = 0;

              totalPrice = oriPrice;

              if (isPromoValid!) {
              } else if (isUseWallet!) {
                if (mounted) {
                  checkoutState!(() {
                    remWalBal = 0;
                    usedBal = 0;
                    isPayLayShow = true;
                    isUseWallet = false;
                  });
                }
                context.read<CartProvider>().setProgress(false);
                setState(() {});
              } else {
                context.read<CartProvider>().setProgress(false);

                checkoutState!(() {});
                setState(() {});
              }
            } else {
              setSnackbar(msg!, context);
              context.read<CartProvider>().setProgress(false);
            }
          }, onError: (error) {
            setSnackbar(error.toString(), context);
          });
        } on TimeoutException catch (_) {
          setSnackbar(getTranslated(context, 'somethingMSg')!, context);
          context.read<CartProvider>().setProgress(false);
        }
      } else {
        if (mounted) {
          checkoutState!(() {
            _isNetworkAvail = false;
          });
        }
        setState(() {});
      }
    }
  }

  deleteProductFromCart(
      int index, int from, List<SectionModel> cartList, int selPos) async {
    _isNetworkAvail = await isNetworkAvailable();

    if (_isNetworkAvail) {
      try {
        context.read<CartProvider>().setProgress(true);

        String varId;
        if (cartList[index].productList![0].availability == "0") {
          varId = cartList[index].productList![0].prVarientList![selPos].id!;
        } else {
          varId = cartList[index].varientId!;
        }

        var parameter = {
          PRODUCT_VARIENT_ID: varId,
          USER_ID: CUR_USERID,
        };
        apiBaseHelper.postAPICall(removeFromCartApi, parameter).then((getdata) {
          bool error = getdata["error"];
          String? msg = getdata["message"];
          if (!error) {
            var data = getdata["data"];

            context.read<UserProvider>().setCartCount(
                (int.parse(context.read<UserProvider>().curCartCount) - 1)
                    .toString());
            cartList.removeWhere(
                (item) => item.varientId == cartList[index].varientId);

            oriPrice = double.parse(data[SUB_TOTAL]);
            if (IS_SHIPROCKET_ON == "0") {
              if (!ISFLAT_DEL) {
                if (addressList.isNotEmpty &&
                    (oriPrice) <
                        double.parse(addressList[selectedAddress!].freeAmt!)) {
                  delCharge = double.parse(
                      addressList[selectedAddress!].deliveryCharge!);
                } else {
                  delCharge = 0;
                }
              } else {
                if ((oriPrice) < double.parse(MIN_AMT!)) {
                  delCharge = double.parse(CUR_DEL_CHR!);
                } else {
                  delCharge = 0;
                }
              }
            }

            totalPrice = 0;

            totalPrice = oriPrice;

            if (isPromoValid!) {
            } else if (isUseWallet!) {
              context.read<CartProvider>().setProgress(false);
              if (mounted) {
                setState(() {
                  remWalBal = 0;
                  usedBal = 0;
                  isPayLayShow = true;
                  isUseWallet = false;
                });
              }
            } else {
              context.read<CartProvider>().setProgress(false);
              setState(() {});
            }
          } else {
            setSnackbar(msg!, context);
          }

          if (mounted) setState(() {});
          context.read<CartProvider>().setProgress(false);
        }, onError: (error) {
          setSnackbar(error.toString(), context);
        });
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
        context.read<CartProvider>().setProgress(false);
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  removeFromCart(int index, bool remove, List<SectionModel> cartList, bool move,
      int selPos) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (!remove &&
        int.parse(cartList[index].qty!) ==
            cartList[index].productList![0].minOrderQuntity) {
      setSnackbar("${getTranslated(context, 'MIN_MSG')}${cartList[index].qty}",
          context);
    } else {
      if (_isNetworkAvail) {
        try {
          context.read<CartProvider>().setProgress(true);

          int? qty;
          if (remove) {
            qty = 0;
          } else {
            qty = (int.parse(cartList[index].qty!) -
                int.parse(cartList[index].productList![0].qtyStepSize!));

            if (qty < cartList[index].productList![0].minOrderQuntity!) {
              qty = cartList[index].productList![0].minOrderQuntity;

              setSnackbar("${getTranslated(context, 'MIN_MSG')}$qty", context);
            }
          }
          String varId;
          if (cartList[index].productList![0].availability == "0") {
            varId = cartList[index].productList![0].prVarientList![selPos].id!;
          } else {
            varId = cartList[index].varientId!;
          }

          var parameter = {
            PRODUCT_VARIENT_ID: varId,
            USER_ID: CUR_USERID,
            QTY: qty.toString(),
          };
          apiBaseHelper.postAPICall(manageCartApi, parameter).then((getdata) {
            bool error = getdata["error"];
            String? msg = getdata["message"];
            if (!error) {
              var data = getdata["data"];

              String? qty = data['total_quantity'];

              context.read<UserProvider>().setCartCount(data['cart_count']);
              if (move == false) {
                if (qty == "0") remove = true;

                if (remove) {
                  cartList.removeWhere(
                      (item) => item.varientId == cartList[index].varientId);
                } else {
                  cartList[index].qty = qty.toString();
                }

                oriPrice = double.parse(data[SUB_TOTAL]);
                if (IS_SHIPROCKET_ON == "0") {
                  if (!ISFLAT_DEL) {
                    if (addressList.isNotEmpty &&
                        (oriPrice) <
                            double.parse(
                                addressList[selectedAddress!].freeAmt!)) {
                      delCharge = double.parse(
                          addressList[selectedAddress!].deliveryCharge!);
                    } else {
                      delCharge = 0;
                    }
                  } else {
                    if ((oriPrice) < double.parse(MIN_AMT!)) {
                      delCharge = double.parse(CUR_DEL_CHR!);
                    } else {
                      delCharge = 0;
                    }
                  }
                }

                totalPrice = 0;

                totalPrice = oriPrice;

                if (isPromoValid!) {
                } else if (isUseWallet!) {
                  context.read<CartProvider>().setProgress(false);
                  if (mounted) {
                    setState(() {
                      remWalBal = 0;
                      usedBal = 0;
                      isPayLayShow = true;
                      isUseWallet = false;
                    });
                  }
                } else {
                  context.read<CartProvider>().setProgress(false);
                  setState(() {});
                }
              } else {
                if (qty == "0") remove = true;

                if (remove) {
                  cartList.removeWhere(
                      (item) => item.varientId == cartList[index].varientId);
                }
              }
            } else {
              setSnackbar(msg!, context);
            }
            if (mounted) setState(() {});
            context.read<CartProvider>().setProgress(false);
          }, onError: (error) {
            setSnackbar(error.toString(), context);
          });
        } on TimeoutException catch (_) {
          setSnackbar(getTranslated(context, 'somethingMSg')!, context);
          context.read<CartProvider>().setProgress(false);
        }
      } else {
        if (mounted) {
          setState(() {
            _isNetworkAvail = false;
          });
        }
      }
    }
  }

  _showContent(BuildContext context) {
    List<SectionModel> cartList = context.read<CartProvider>().cartList;

    if (cartList.isEmpty) {
      return cartEmpty();
    }

    return Container(
      padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
      color: Theme.of(context).colorScheme.lightWhite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              controller: _scrollControllerOnCartItems,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: cartList.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return listItem(index, cartList);
                    },
                  ),
                  Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.white,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(5),
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 8),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 5),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      getTranslated(
                                          context, 'PROMO_CODE_DIS_LBL')!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .lightBlack2),
                                    ),
                                    Text(
                                      'Giảm giá 20% ',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .lightBlack2),
                                    )
                                  ],
                                ),
                                if (cartList.isNotEmpty)
                                  Row(
                                    //  mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(getTranslated(
                                          context, 'TOTAL_PRICE')!),
                                      Text(
                                        '${getPriceFormat(context, oriPrice)!} ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium!
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .fontColor),
                                      ),
                                    ],
                                  ),
                              ],
                            )),
                      ]),
                ],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio(
                          fillColor: MaterialStateColor.resolveWith((states) {
                            return colors.primary;
                          }),
                          groupValue: isStorePickUp,
                          value: "false",
                          onChanged: (val) {
                            setState(() {
                              isStorePickUp = val.toString();
                              if (selAddress == "" || selAddress!.isEmpty) {}
                            });
                          },
                        ),
                        Text(
                          getTranslated(context, 'DOOR_STEP_DEL_LBL')!,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall!
                              .copyWith(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).colorScheme.fontColor),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Radio(
                          fillColor: MaterialStateColor.resolveWith((states) {
                            return colors.primary;
                          }),
                          hoverColor: colors.primary,
                          groupValue: isStorePickUp,
                          value: "true",
                          onChanged: (val) {
                            setState(() {
                              isStorePickUp = val.toString();
                            });
                          },
                        ),
                        Text(getTranslated(context, 'PICKUP_STORE_LBL')!,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .fontColor))
                      ])),
                ],
              ),
              Center(
                child: SimBtn(
                    width: 0.9,
                    height: 35,
                    title: getTranslated(context, 'PROCEED_CHECKOUT'),
                    onBtnSelected: () async {
                      checkout(cartList);
                    }),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> promoEmpty() async {
    setState(() {
      totalPrice = totalPrice + promoAmt;
    });
  }

  cartEmpty() {
    return Center(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          noCartImage(context),
          noCartText(context),
          noCartDec(context),
          shopNow()
        ]),
      ),
    );
  }

  getAllPromo() {}

  noCartImage(BuildContext context) {
    return Image.asset(
      'assets/images/Empty_cart.png',
      fit: BoxFit.contain,
    );
  }

  noCartText(BuildContext context) {
    return Text(getTranslated(context, 'NO_CART')!,
        style: Theme.of(context)
            .textTheme
            .headlineSmall!
            .copyWith(color: colors.primary, fontWeight: FontWeight.normal));
  }

  noCartDec(BuildContext context) {
    return Container(
      padding:
          const EdgeInsetsDirectional.only(top: 30.0, start: 30.0, end: 30.0),
      child: Text(getTranslated(context, 'CART_DESC')!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).colorScheme.lightBlack2,
                fontWeight: FontWeight.normal,
              )),
    );
  }

  shopNow() {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 28.0),
      child: CupertinoButton(
        child: Container(
            width: deviceWidth! * 0.7,
            height: 45,
            alignment: FractionalOffset.center,
            decoration: const BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.all(Radius.circular(50.0)),
            ),
            child: Text(getTranslated(context, 'SHOP_NOW')!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    color: Theme.of(context).colorScheme.white,
                    fontWeight: FontWeight.normal))),
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/home', (Route<dynamic> route) => false);
        },
      ),
    );
  }

  checkout(List<SectionModel> cartList) {
    print("cartList*****${cartList.length}");
    deviceHeight = MediaQuery.of(context).size.height;
    deviceWidth = MediaQuery.of(context).size.width;
    payMethod = "ZakumiFi Coin";
    selectedMethod = 0;
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10), topRight: Radius.circular(10))),
        builder: (builder) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            checkoutState = setState;
            return Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: Scaffold(
                  resizeToAvoidBottomInset: false,
                  body: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: <Widget>[
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    address(),
                                    payment(),
                                    cartItems(cartList),
                                    orderSummary(cartList),
                                  ],
                                ),
                              ),
                            ),
                            Selector<CartProvider, bool>(
                              builder: (context, data, child) {
                                return showCircularProgress(
                                    data, colors.primary);
                              },
                              selector: (_, provider) => provider.isProgress,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        width: deviceWidth,
                        color: Theme.of(context).colorScheme.white,
                        child: SimBtn(
                            height: 45,
                            width: 0.9,
                            title: getTranslated(context, 'PLACE_ORDER'),
                            onBtnSelected: /*_placeOrder
                                                  ?*/
                                () {
                              checkoutState!(() {
                                _placeOrder = true;
                              });

                              confirmDialog(cartList);
                            } /*: null*/),
                      ),
                    ],
                  ),
                ));
          });
        });
  }

  Future<Map<String, dynamic>> updateOrderStatus(
      {required String status, required String orderID}) async {
    var parameter = {ORDER_ID: orderID, STATUS: status};
    var result = await ApiBaseHelper().postAPICall(updateOrderApi, parameter);
    return {'error': result['error'], 'message': result['message']};
  }

  updateCheckout() {
    if (mounted) checkoutState!(() {});
  }

  updateProgress(bool progress) {
    if (mounted) {
      checkoutState!(() {
        context.read<CartProvider>().setProgress(progress);
      });
    }
  }

  Future<void> placeOrder(String? tranId) async {
    context.read<CartProvider>().setProgress(true);

    context.read<UserProvider>().setCartCount("0");

    clearAll();

    Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(
            builder: (BuildContext context) => const OrderSuccess()),
        ModalRoute.withName('/home'));

    context.read<CartProvider>().setProgress(false);
  }

  Future<void> paypalPayment(String orderId) async {
    try {
      var parameter = {
        USER_ID: CUR_USERID,
        ORDER_ID: orderId,
        AMOUNT: usedBal > 0
            ? totalPrice.toString()
            : isStorePickUp == "false"
                ? (totalPrice + delCharge).toString()
                : totalPrice.toString()
      };
      apiBaseHelper.postAPICall(paypalTransactionApi, parameter).then(
          (getdata) {
        bool error = getdata["error"];
        String? msg = getdata["message"];
        if (!error) {
          String? data = getdata["data"];
          Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (BuildContext context) => PaypalWebview(
                        url: data,
                        from: "order",
                        orderId: orderId,
                      )));
        } else {
          setSnackbar(msg!, context);
        }
        context.read<CartProvider>().setProgress(false);
      }, onError: (error) {
        setSnackbar(error.toString(), context);
      });
    } on TimeoutException catch (_) {
      setSnackbar(getTranslated(context, 'somethingMSg')!, context);
    }
  }

  Future<void> addTransaction(String? tranId, String orderID, String? status,
      String? msg, bool redirect) async {
    try {
      var parameter = {
        USER_ID: CUR_USERID,
        ORDER_ID: orderID,
        TYPE: payMethod,
        TXNID: tranId,
        AMOUNT: usedBal > 0
            ? totalPrice.toString()
            : isStorePickUp == "false"
                ? (totalPrice + delCharge).toString()
                : totalPrice.toString(),
        STATUS: status,
        MSG: msg
      };

      print("transaction param*****$parameter");
      apiBaseHelper.postAPICall(addTransactionApi, parameter).then((getdata) {
        bool error = getdata["error"];
        String? msg1 = getdata["message"];
        if (!error) {
          if (redirect) {
            context.read<UserProvider>().setCartCount("0");
            clearAll();

            Navigator.pushAndRemoveUntil(
                context,
                CupertinoPageRoute(
                    builder: (BuildContext context) => const OrderSuccess()),
                ModalRoute.withName('/home'));
          }
        } else {
          setSnackbar(msg1!, context);
        }
      }, onError: (error) {
        setSnackbar(error.toString(), context);
      });
    } on TimeoutException catch (_) {
      setSnackbar(getTranslated(context, 'somethingMSg')!, context);
    }
  }

  Future<void> deleteOrders(String orderId) async {
    try {
      var parameter = {
        ORDER_ID: orderId,
      };

      apiBaseHelper.postAPICall(deleteOrderApi, parameter).then((getdata) {
        if (mounted) {
          setState(() {});
        }

        Navigator.of(context).pop();
      }, onError: (error) {
        setSnackbar(error.toString(), context);
      });
    } on TimeoutException catch (_) {
      setSnackbar(getTranslated(context, 'somethingMSg')!, context);

      setState(() {});
    }
  }

  String _getReference() {
    String platform;
    if (Platform.isIOS) {
      platform = 'iOS';
    } else {
      platform = 'Android';
    }

    return 'ChargedFrom${platform}_${DateTime.now().millisecondsSinceEpoch}';
  }

  address() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on),
                Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8.0),
                    child: Text(
                      getTranslated(context, 'SHIPPING_DETAIL') ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.fontColor),
                    )),
              ],
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Lê Hoài Nam')),
                      InkWell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            getTranslated(context, 'CHANGE')!,
                            style: const TextStyle(
                              color: colors.primary,
                            ),
                          ),
                        ),
                        onTap: () async {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (context) => AddAddress(
                                      update: false,
                                      index: addressList.length,
                                    )),
                          ).then((value) async {
                            //await getShipRocketDeliveryCharge();
                          });
                        },
                      ),
                    ],
                  ),
                  Text(
                    "2/4/64A Lê Thúc Hoạch, phường Phú Thọ Hòa, quận Tân Phú, Tp. Hồ Chí Minh",
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.lightBlack),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Row(
                      children: [
                        Text(
                          '0973962274',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.lightBlack),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            )
            /*
            addressList.isNotEmpty
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child:
                                    Text('Lê Hoài Nam')),
                            InkWell(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  getTranslated(context, 'CHANGE')!,
                                  style: const TextStyle(
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                              onTap: () async {
                                await Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                            builder: (BuildContext context) =>
                                                ManageAddress(
                                                    home: false,
                                                    update: updateCheckout,
                                                    updateProgress:
                                                        updateProgress)))
                                    .then((value) {
                                  checkoutState!(() {
                                    deliverable = false;
                                  });
                                });
                              },
                            ),
                          ],
                        ),
                        Text(
                          "2/4/64A Lê Thúc Hoạch, phường Phú Thọ Hòa, quận Tân Phú, Tp. Hồ Chí Minh",
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.lightBlack),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: Row(
                            children: [
                              Text(
                                '0973962274',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .lightBlack),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8.0),
                    child: InkWell(
                      child: Text(
                        getTranslated(context, 'ADDADDRESS')!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.fontColor,
                        ),
                      ),
                      onTap: () async {
                        ScaffoldMessenger.of(context).removeCurrentSnackBar();
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (context) => AddAddress(
                                    update: false,
                                    index: addressList.length,
                                  )),
                        ).then((value) async {
                          //await getShipRocketDeliveryCharge();
                        });
                        if (mounted) setState(() {});
                      },
                    ),
                  )*/
          ],
        ),
      ),
    );
  }

  payment() {
    return Card(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () async {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          msg = 'Select Payment Method';
          await Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (BuildContext context) =>
                      Payment(updateCheckout, msg)));
          if (mounted) checkoutState!(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.payment),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8.0),
                    child: Text(
                      getTranslated(context, 'SELECT_PAYMENT')!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.fontColor,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              payMethod != null && payMethod != ''
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          Text(
                            payMethod!,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent),
                          )
                        ],
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }

  cartItems(List<SectionModel> cartList) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: cartList.length,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return cartItem(index, cartList);
      },
    );
  }

  orderSummary(List<SectionModel> cartList) {
    return Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${getTranslated(context, 'ORDER_SUMMARY')!} (${cartList.length} items)",
                style: TextStyle(
                    color: Theme.of(context).colorScheme.fontColor,
                    fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    getTranslated(context, 'SUBTOTAL')!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.lightBlack2),
                  ),
                  Text(
                    '${getPriceFormat(context, oriPrice)!} ',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.fontColor,
                        fontWeight: FontWeight.bold),
                  )
                ],
              ),
              if (cartList[0].productList![0].productType != 'digital_product')
                if (isStorePickUp == "false")
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        getTranslated(context, 'DELIVERY_CHARGE')!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.lightBlack2),
                      ),
                      Text(
                        '${getPriceFormat(context, delCharge)!} ',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.fontColor,
                            fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
              if (IS_SHIPROCKET_ON == "1" &&
                  isStorePickUp == "false" &&
                  shipRocketDeliverableDate != "" &&
                  !isLocalDelCharge!)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      getTranslated(context, 'DELIVERY_DAY_LBL')!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.lightBlack2),
                    ),
                    Text(
                      shipRocketDeliverableDate,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.fontColor,
                          fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              isPromoValid!
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          getTranslated(context, 'PROMO_CODE_DIS_LBL')!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.lightBlack2),
                        ),
                        Text(
                          '${getPriceFormat(context, promoAmt)!} ',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.fontColor,
                              fontWeight: FontWeight.bold),
                        )
                      ],
                    )
                  : Container(),
              isUseWallet!
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          getTranslated(context, 'WALLET_BAL')!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.lightBlack2),
                        ),
                        Text(
                          '${getPriceFormat(context, usedBal)!} ',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.fontColor,
                              fontWeight: FontWeight.bold),
                        )
                      ],
                    )
                  : Container(),
            ],
          ),
        ));
  }

  bool validateAndSave() {
    final form = _formkey.currentState!;
    form.save();
    if (form.validate()) {
      return true;
    }
    return false;
  }

  void confirmDialog(List<SectionModel> cartList) {
    showGeneralDialog(
        barrierColor: Theme.of(context).colorScheme.black.withOpacity(0.5),
        transitionBuilder: (context, a1, a2, widget) {
          return Transform.scale(
            scale: a1.value,
            child: Opacity(
                opacity: a1.value,
                child: AlertDialog(
                  contentPadding: const EdgeInsets.all(0),
                  elevation: 2.0,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(5.0))),
                  content: Form(
                    key: _formkey,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20.0, 20.0, 0, 2.0),
                              child: Text(
                                getTranslated(context, 'CONFIRM_ORDER')!,
                                style: Theme.of(this.context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .fontColor),
                              )),
                          Divider(
                              color: Theme.of(context).colorScheme.lightBlack),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20.0, 0, 20.0, 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        getTranslated(context, 'TOTAL_PRICE')!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .lightBlack2),
                                      ),
                                      Text(
                                        getPriceFormat(context, oriPrice)!,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .fontColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: TextField(
                                      controller: noteC,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10),
                                        border: InputBorder.none,
                                        filled: true,
                                        fillColor:
                                            colors.primary.withOpacity(0.1),
                                        hintText:
                                            getTranslated(context, 'NOTE'),
                                      ),
                                    )),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: TextFormField(
                                    validator: (val) => validateEmail(
                                        val!,
                                        getTranslated(
                                            context, 'EMAIL_REQUIRED'),
                                        getTranslated(context, 'VALID_EMAIL')),
                                    controller: emailController,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10),
                                      border: InputBorder.none,
                                      filled: true,
                                      fillColor:
                                          colors.primary.withOpacity(0.1),
                                      hintText: getTranslated(
                                          context, 'ENTER_EMAIL_ID_LBL'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                  ),
                  actions: <Widget>[
                    TextButton(
                        child: Text(getTranslated(context, 'CANCEL')!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.lightBlack,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          checkoutState!(() {
                            _placeOrder = true;
                            isPromoValid = false;
                          });
                          Navigator.pop(context);
                        }),
                    TextButton(
                        child: Text(getTranslated(context, 'DONE')!,
                            style: const TextStyle(
                                color: colors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          if (payMethod == 'CHUYỂN KHOẢN') {
                            Navigator.pop(context);
                            bankTransfer();
                          } else if (payMethod == 'ZakumiFi Coin') {
                            Navigator.pop(context);
                            voidCoinTemp();
                          } else if (payMethod == 'PAYPAL') {
                            Navigator.pop(context);
                            paypalSend();
                          } else if (payMethod == 'Coin') {
                            Navigator.pop(context);
                            coinbasePayment();
                          } else {
                            Navigator.pop(context);
                            placeOrder('');
                          }
                        })
                  ],
                )),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        barrierDismissible: false,
        barrierLabel: '',
        context: context,
        pageBuilder: (context, animation1, animation2) {
          return Container();
        }).then((value) => setState(() {
          confDia = true;
        }));
  }

  coinbasePayment() async {
    context.read<CartProvider>().setProgress(true);
    Coinbase coinbase =
        Coinbase('c1e57c53-f88c-4ef9-92ae-8db91fa47b5f', debug: true);
    CheckoutObject checkout = await coinbase.createCheckout(
        description: 'Test payment with coinbase',
        name: 'Order 07654',
        pricingType: PricingType.fixedPrice,
        amount: 1,
        currency: CurrencyType.usd);
    context.read<CartProvider>().setProgress(false);
    CheckoutObject charge = await coinbase.viewCheckout(checkout.id!);
    final Uri _url = Uri.parse( 'https://commerce.coinbase.com/checkout/${charge.id}');
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
    placeOrder('');
    /*
    Navigator.push(
      context,
      CupertinoPageRoute(
          builder: (context) => WebviewCustom(
                appName: 'Payment Coin',
                url: 'https://commerce.coinbase.com/checkout/${charge.id}',
              )),
    ).then((value) async {
      placeOrder('');
    });*/
  }

  paypalSend() async {
    _FlutterPaypalNativePlugin.addPurchaseUnit(
      FPayPalPurchaseUnit(
        // random prices
        amount: 1,

        ///please use your own algorithm for referenceId. Maybe ProductID?
        referenceId: FPayPalStrHelper.getRandomString(16),
      ),
    );
    _FlutterPaypalNativePlugin.makeOrder(
      action: FPayPalUserAction.payNow,
    );
  }

  voidCoinTemp() {
    showGeneralDialog(
        barrierColor: Theme.of(context).colorScheme.black.withOpacity(0.5),
        transitionBuilder: (context, a1, a2, widget) {
          return Transform.scale(
            scale: a1.value,
            child: Opacity(
                opacity: a1.value,
                child: AlertDialog(
                  contentPadding: const EdgeInsets.all(0),
                  elevation: 2.0,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(5.0))),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20.0, 20.0, 0, 2.0),
                            child: Text(
                              'THANH TOÁN QUA VÍ COIN',
                              style: Theme.of(this.context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .fontColor),
                            )),
                        Divider(
                            color: Theme.of(context).colorScheme.lightBlack),
                        Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20.0, 0, 20.0, 0),
                            child: Text('Thanh toán bằng coi ZakumiFi',
                                style: Theme.of(context).textTheme.bodySmall)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 10),
                          child: Text(
                            'Thông tin địa chỉ ví',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .fontColor),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                          ),
                          child: Wrap(
                            children: [
                              Text(
                                "0xb4495855C1d723E0515fCC04a38b7F7FcBdcf727",
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              IconButton(
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(
                                        text:
                                            "0xb4495855C1d723E0515fCC04a38b7F7FcBdcf727"));
                                  },
                                  icon: Icon(Icons.copy))
                            ],
                          ),
                        ),
                      ]),
                  actions: <Widget>[
                    TextButton(
                        child: Text(getTranslated(context, 'CANCEL')!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.lightBlack,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          checkoutState!(() {
                            _placeOrder = true;
                          });
                          Navigator.pop(context);
                        }),
                    TextButton(
                        child: Text(getTranslated(context, 'DONE')!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.fontColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(context);

                          context.read<CartProvider>().setProgress(true);

                          placeOrder('');
                        })
                  ],
                )),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        barrierDismissible: false,
        barrierLabel: '',
        context: context,
        pageBuilder: (context, animation1, animation2) {
          return Container();
        });
  }

  void bankTransfer() {
    showGeneralDialog(
        barrierColor: Theme.of(context).colorScheme.black.withOpacity(0.5),
        transitionBuilder: (context, a1, a2, widget) {
          return Transform.scale(
            scale: a1.value,
            child: Opacity(
                opacity: a1.value,
                child: AlertDialog(
                  contentPadding: const EdgeInsets.all(0),
                  elevation: 2.0,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(5.0))),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20.0, 20.0, 0, 2.0),
                            child: Text(
                              'CHUYỂN KHOẢN',
                              style: Theme.of(this.context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .fontColor),
                            )),
                        Divider(
                            color: Theme.of(context).colorScheme.lightBlack),
                        Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20.0, 0, 20.0, 0),
                            child: Text(getTranslated(context, 'BANK_INS')!,
                                style: Theme.of(context).textTheme.bodySmall)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 10),
                          child: Text(
                            getTranslated(context, 'ACC_DETAIL')!,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .fontColor),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                          ),
                          child: Text(
                            "${getTranslated(context, 'ACCNAME')!} : Le Hoài Nam",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                          ),
                          child: Text(
                            "${getTranslated(context, 'ACCNO')!} : 1525678",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                          ),
                          child: Text(
                            "${getTranslated(context, 'BANKNAME')!} : Vietcombank",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                          ),
                          child: Text(
                            "${getTranslated(context, 'BANKCODE')!} : 12345678",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                          ),
                          child: Text(
                            "${getTranslated(context, 'EXTRADETAIL')!} : 05/25",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        )
                      ]),
                  actions: <Widget>[
                    TextButton(
                        child: Text(getTranslated(context, 'CANCEL')!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.lightBlack,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          checkoutState!(() {
                            _placeOrder = true;
                          });
                          Navigator.pop(context);
                        }),
                    TextButton(
                        child: Text(getTranslated(context, 'DONE')!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.fontColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(context);

                          context.read<CartProvider>().setProgress(true);

                          placeOrder('');
                        })
                  ],
                )),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        barrierDismissible: false,
        barrierLabel: '',
        context: context,
        pageBuilder: (context, animation1, animation2) {
          return Container();
        });
  }

  Future<void> checkDeliverable(int from) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        context.read<CartProvider>().setProgress(true);

        var parameter = {
          USER_ID: CUR_USERID,
          ADD_ID: selAddress,
        };
        apiBaseHelper.postAPICall(checkCartDelApi, parameter).then((getdata) {
          bool error = getdata["error"];
          String? msg = getdata["message"];
          List data = getdata["data"];
          context.read<CartProvider>().setProgress(false);

          if (error) {
            deliverableList =
                (data).map((data) => Model.checkDeliverable(data)).toList();

            checkoutState!(() {
              deliverable = false;
              _placeOrder = true;
            });

            setSnackbar(msg!, context);
            context.read<CartProvider>().setProgress(false);
          } else {
            print("data****$data");
            if (data.isEmpty) {
              print("data inner");
              setState(() {
                deliverable = true;
              });
              if (mounted) {
                if (checkoutState != null) {
                  checkoutState!(() {});
                }
              }
            } else {
              bool isDeliverible = false;
              bool? isShipRocket;
              deliverableList =
                  (data).map((data) => Model.checkDeliverable(data)).toList();

              for (int i = 0; i < deliverableList.length; i++) {
                if (deliverableList[i].isDel == false) {
                  isDeliverible = false;
                  break;
                } else {
                  isDeliverible = true;
                  if (deliverableList[i].delBy == "standard_shipping") {
                    isShipRocket = true;
                  }
                }
              }
            }
            context.read<CartProvider>().setProgress(false);
          }
        }, onError: (error) {
          setSnackbar(error.toString(), context);
        });
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  attachPrescriptionImages(List<SectionModel> cartList) {
    bool isAttachReq = false;
    for (int i = 0; i < cartList.length; i++) {
      if (cartList[i].productList![0].is_attch_req == "1") {
        isAttachReq = true;
      }
    }
    return ALLOW_ATT_MEDIA == "1" && isAttachReq
        ? Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        getTranslated(context, 'ADD_ATT_REQ')!,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            color: Theme.of(context).colorScheme.lightBlack),
                      ),
                      SizedBox(
                        height: 30,
                        child: IconButton(
                            icon: const Icon(
                              Icons.add_photo_alternate,
                              color: colors.primary,
                              size: 20.0,
                            ),
                            onPressed: () {
                              _imgFromGallery();
                            }),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsetsDirectional.only(
                        start: 20.0, end: 20.0, top: 5),
                    height: prescriptionImages.isNotEmpty ? 180 : 0,
                    child: Row(
                      children: [
                        Expanded(
                            child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: prescriptionImages.length,
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, i) {
                            return InkWell(
                              child: Stack(
                                alignment: AlignmentDirectional.topEnd,
                                children: [
                                  Image.file(
                                    prescriptionImages[i],
                                    width: 180,
                                    height: 180,
                                  ),
                                  Container(
                                      color:
                                          Theme.of(context).colorScheme.black26,
                                      child: const Icon(
                                        Icons.clear,
                                        size: 15,
                                      ))
                                ],
                              ),
                              onTap: () {
                                checkoutState!(() {
                                  prescriptionImages.removeAt(i);
                                });
                              },
                            );
                          },
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        : Container();
  }

  _imgFromGallery() async {}
}
