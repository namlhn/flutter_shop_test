import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:eshop/Helper/ApiBaseHelper.dart';
import 'package:eshop/Helper/Color.dart';
import 'package:eshop/Helper/Constant.dart';
import 'package:eshop/Helper/Session.dart';
import 'package:eshop/Helper/SqliteData.dart';
import 'package:eshop/Helper/String.dart';
import 'package:eshop/Model/Model.dart';
import 'package:eshop/Model/OfferImages.dart';
import 'package:eshop/Model/Section_Model.dart';
import 'package:eshop/Provider/CartProvider.dart';
import 'package:eshop/Provider/CategoryProvider.dart';
import 'package:eshop/Provider/FavoriteProvider.dart';
import 'package:eshop/Provider/HomeProvider.dart';
import 'package:eshop/Provider/UserProvider.dart';
import 'package:eshop/Screen/Login.dart';
import 'package:eshop/Screen/Search.dart';
import 'package:eshop/Screen/SubCategory.dart';
import 'package:eshop/ui/widgets/AppBtn.dart';
import 'package:eshop/ui/widgets/SimBtn.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Provider/ProductProvider.dart';
import '../ui/styles/DesignConfig.dart';
import '../ui/styles/Validators.dart';

import 'ProductList.dart';
import 'Product_DetailNew.dart';
import 'SectionList.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

List<SectionModel> sectionList = [];
List<Product> catList = [];
List<Product> popularList = [];
ApiBaseHelper apiBaseHelper = ApiBaseHelper();
List<String> tagList = [];
List<Product> sellerList = [];
List<Model> homeSliderList = [];
List<Widget> pages = [];
int count = 1;

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage>, TickerProviderStateMixin {
  bool _isNetworkAvail = true;
  final _controller = PageController();
  late Animation buttonSqueezeanimation;
  late AnimationController buttonController;
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();

  final ScrollController _scrollBottomBarController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  double beginAnim = 0.0;

  double endAnim = 1.0;
  var db = DatabaseHelper();
  List<String> proIds = [];
  List<Product> mostLikeProList = [];
  List<String> proIds1 = [];
  List<Product> mostFavProList = [];
  PopUpOfferImage popUpOffer = PopUpOfferImage();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    callApi();
   // showPopUpOfferDialog();
    buttonController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);

    buttonSqueezeanimation = Tween(
      begin: deviceWidth! * 0.7,
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: buttonController,
      curve: const Interval(
        0.0,
        0.150,
      ),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) => _animateSlider());
  }

  @override
  void dispose() {
    _scrollBottomBarController.removeListener(() {});
    _controller.dispose();
    buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    hideAppbarAndBottomBarOnScroll(_scrollBottomBarController, context);
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.lightWhite,
        body: _isNetworkAvail
            ? RefreshIndicator(
                color: colors.primary,
                key: _refreshIndicatorKey,
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  //  controller: _scrollBottomBarController,
                  child: Column(
                    children: [
                      _deliverPincode(),
                      _getSearchBar(),
                      _catList(),
                      _slider(),
                      _section(),
                      //_mostLike(),
                    ],
                  ),
                ))
            : noInternet(context));
  }

  Future<void> _refresh() {
    // context.read<HomeProvider>().setCatLoading(true);
    // context.read<HomeProvider>().setSecLoading(true);
    //context.read<HomeProvider>().setOfferLoading(true);
    //context.read<HomeProvider>().setMostLikeLoading(true);
    // context.read<HomeProvider>().setSliderLoading(true);
    // context.read<CategoryProvider>().setCurSelected(0);
    proIds.clear();

    return callApi();
  }

  Widget _slider() {
    double height = deviceWidth! / 2.2;

    return Stack(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: PageView.builder(
            itemCount: homeSliderList.length,
            scrollDirection: Axis.horizontal,
            controller: _controller,
            physics: const AlwaysScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                context.read<HomeProvider>().setCurSlider(index);
              });
            },
            itemBuilder: (BuildContext context, int index) {
              return pages[index];
            },
          ),
        ),
        Positioned(
          bottom: 0,
          height: 40,
          left: 0,
          width: deviceWidth,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: map<Widget>(
              homeSliderList,
              (index, url) {
                return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: context.read<HomeProvider>().curSlider == index
                        ? 25
                        : 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 2.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5.0),
                      color: context.read<HomeProvider>().curSlider == index
                          ? Theme.of(context).colorScheme.fontColor
                          : Theme.of(context)
                              .colorScheme
                              .lightBlack
                              .withOpacity(0.7),
                    ));
              },
            ),
          ),
        ),
      ],
    );
  }

  void _animateSlider() {
    Future.delayed(const Duration(seconds: 10)).then((_) {
      if (mounted) {
        int nextPage = _controller.hasClients
            ? _controller.page!.round() + 1
            : _controller.initialPage;

        if (nextPage == homeSliderList.length) {
          nextPage = 0;
        }
        if (_controller.hasClients) {
          _controller
              .animateToPage(nextPage,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.linear)
              .then((_) {
            _animateSlider();
          });
        }
      }
    });
  }

  _singleSection(int index) {
    Color back;
    int pos = index % 5;
    if (pos == 0) {
      back = Theme.of(context).colorScheme.back1;
    } else if (pos == 1) {
      back = Theme.of(context).colorScheme.back2;
    } else if (pos == 2) {
      back = Theme.of(context).colorScheme.back3;
    } else if (pos == 3) {
      back = Theme.of(context).colorScheme.back4;
    } else {
      back = Theme.of(context).colorScheme.back5;
    }

    return sectionList[index].productList!.isNotEmpty
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                          margin: const EdgeInsets.only(bottom: 40),
                          decoration: BoxDecoration(
                              color: back,
                              borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20)))),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _getHeading(
                            sectionList[index].title ?? "", index, 1, []),
                        _getSection(index),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          )
        : Container();
  }

  _getHeading(String title, int index, int from, List<Product> productList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (from == 1)
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerRight,
              children: <Widget>[
                Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
                    color: colors.yellow,
                  ),
                  padding: const EdgeInsetsDirectional.only(
                      start: 12, bottom: 3, top: 3, end: 12),
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: colors.blackTemp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        Padding(
            padding: const EdgeInsetsDirectional.only(start: 12.0, end: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                      from == 2 ? title : sectionList[index].shortDesc ?? "",
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: Theme.of(context).colorScheme.fontColor)),
                ),
                TextButton(
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero, //
                        backgroundColor: (Theme.of(context).colorScheme.white),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5)),
                    child: Text(
                      getTranslated(context, 'SHOP_NOW')!,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Theme.of(context).colorScheme.fontColor,
                          fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      SectionModel model = sectionList[index];
                      Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => SectionList(
                              index: index,
                              section_model: model,
                              from: from,
                              productList: productList,
                            ),
                          ));
                    }),
              ],
            )),
      ],
    );
  }

/*  _getOfferImage(index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: InkWell(
        child: CachedNetworkImage(
            imageUrl: offerImages[index].image!,
            fadeInDuration: const Duration(milliseconds: 150),
            width: double.maxFinite,
            errorWidget: (context, error, stackTrace) => erroWidget(50),

            // errorWidget: (context, url, e) => return return placeHolder(50),
            placeholder: (BuildContext context, url) {
              return Image.asset(
                "assets/images/sliderph.png",
              );
            }),
        onTap: () {
          if (offerImages[index].type == "products") {
            Product? item = offerImages[index].list;
            currentHero = homeHero;
            Navigator.push(
              context,
              PageRouteBuilder(
                  //transitionDuration: Duration(seconds: 1),
                  pageBuilder: (_, __, ___) => ProductDetail(
                        secPos: 0, index: 0, list: true, id: item!.id!,
                        //  title: sectionList[secPos].title,
                      )),
            );
          } else if (offerImages[index].type == "categories") {
            Product item = offerImages[index].list;
            if (item.subList == null || item.subList!.isEmpty) {
              Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => ProductList(
                      name: item.name,
                      id: item.id,
                      tag: false,
                      fromSeller: false,
                    ),
                  ));
            } else {
              Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => SubCategory(
                      title: item.name!,
                      subList: item.subList,
                    ),
                  ));
            }
          }
        },
      ),
    );
  }*/

  _getSection(int i) {
    var orient = MediaQuery.of(context).orientation;

    return sectionList[i].style == DEFAULT
        ? Padding(
            padding: const EdgeInsets.all(15.0),
            child: GridView.count(
                padding: const EdgeInsetsDirectional.only(top: 5),
                crossAxisCount: 2,
                shrinkWrap: true,
                //childAspectRatio: 0.8,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(
                  sectionList[i].productList!.length < 4
                      ? sectionList[i].productList!.length
                      : 4,
                  (index) {
                    return productItem(
                        i,
                        index,
                        index % 2 == 0 ? true : false,
                        sectionList[i].productList![index],
                        1,
                        sectionList[i].productList!.length);
                  },
                )),
          )
        : sectionList[i].style == STYLE1
            ? sectionList[i].productList!.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Row(
                      children: [
                        Flexible(
                            flex: 3,
                            fit: FlexFit.loose,
                            child: SizedBox(
                                height: orient == Orientation.portrait
                                    ? deviceHeight! * 0.4
                                    : deviceHeight,
                                child: sectionList[i].productList!.length ==
                                            1 ||
                                        sectionList[i].productList!.length > 1
                                    ? productItem(
                                        i,
                                        0,
                                        true,
                                        sectionList[i].productList![0],
                                        1,
                                        sectionList[i].productList!.length)
                                    : Container())),
                        Flexible(
                          flex: 2,
                          fit: FlexFit.loose,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                  height: orient == Orientation.portrait
                                      ? deviceHeight! * 0.2
                                      : deviceHeight! * 0.5,
                                  child: sectionList[i].productList!.length ==
                                              2 ||
                                          sectionList[i].productList!.length > 2
                                      ? productItem(
                                          i,
                                          1,
                                          false,
                                          sectionList[i].productList![1],
                                          1,
                                          sectionList[i].productList!.length)
                                      : Container()),
                              SizedBox(
                                  height: orient == Orientation.portrait
                                      ? deviceHeight! * 0.2
                                      : deviceHeight! * 0.5,
                                  child: sectionList[i].productList!.length ==
                                              3 ||
                                          sectionList[i].productList!.length > 3
                                      ? productItem(
                                          i,
                                          2,
                                          false,
                                          sectionList[i].productList![2],
                                          1,
                                          sectionList[i].productList!.length)
                                      : Container()),
                            ],
                          ),
                        ),
                      ],
                    ))
                : Container()
            : sectionList[i].style == STYLE2
                ? Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Row(
                      children: [
                        Flexible(
                          flex: 2,
                          fit: FlexFit.loose,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                  height: orient == Orientation.portrait
                                      ? deviceHeight! * 0.2
                                      : deviceHeight! * 0.5,
                                  child: sectionList[i].productList!.length ==
                                              1 ||
                                          sectionList[i].productList!.length > 1
                                      ? productItem(
                                          i,
                                          0,
                                          true,
                                          sectionList[i].productList![0],
                                          1,
                                          sectionList[i].productList!.length)
                                      : Container()),
                              SizedBox(
                                  height: orient == Orientation.portrait
                                      ? deviceHeight! * 0.2
                                      : deviceHeight! * 0.5,
                                  child: sectionList[i].productList!.length ==
                                              2 ||
                                          sectionList[i].productList!.length > 2
                                      ? productItem(
                                          i,
                                          1,
                                          true,
                                          sectionList[i].productList![1],
                                          1,
                                          sectionList[i].productList!.length)
                                      : Container()),
                            ],
                          ),
                        ),
                        Flexible(
                            flex: 3,
                            fit: FlexFit.loose,
                            child: SizedBox(
                                height: orient == Orientation.portrait
                                    ? deviceHeight! * 0.4
                                    : deviceHeight,
                                child: sectionList[i].productList!.length ==
                                            3 ||
                                        sectionList[i].productList!.length > 3
                                    ? productItem(
                                        i,
                                        2,
                                        false,
                                        sectionList[i].productList![2],
                                        1,
                                        sectionList[i].productList!.length)
                                    : Container())),
                      ],
                    ))
                : sectionList[i].style == STYLE3
                    ? Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                                flex: 1,
                                fit: FlexFit.loose,
                                child: SizedBox(
                                    height: orient == Orientation.portrait
                                        ? deviceHeight! * 0.3
                                        : deviceHeight! * 0.6,
                                    child: sectionList[i].productList!.length ==
                                                1 ||
                                            sectionList[i].productList!.length >
                                                1
                                        ? productItem(
                                            i,
                                            0,
                                            false,
                                            sectionList[i].productList![0],
                                            1,
                                            sectionList[i].productList!.length)
                                        : Container())),
                            SizedBox(
                              height: orient == Orientation.portrait
                                  ? deviceHeight! * 0.2
                                  : deviceHeight! * 0.5,
                              child: Row(
                                children: [
                                  Flexible(
                                      flex: 1,
                                      fit: FlexFit.loose,
                                      child: sectionList[i]
                                                      .productList!
                                                      .length >=
                                                  2 ||
                                              sectionList[i]
                                                      .productList!
                                                      .length >
                                                  2
                                          ? productItem(
                                              i,
                                              1,
                                              true,
                                              sectionList[i].productList![1],
                                              1,
                                              sectionList[i]
                                                  .productList!
                                                  .length)
                                          : Container()),
                                  Flexible(
                                      flex: 1,
                                      fit: FlexFit.loose,
                                      child: sectionList[i]
                                                      .productList!
                                                      .length ==
                                                  3 ||
                                              sectionList[i]
                                                      .productList!
                                                      .length >
                                                  3
                                          ? productItem(
                                              i,
                                              2,
                                              true,
                                              sectionList[i].productList![2],
                                              1,
                                              sectionList[i]
                                                  .productList!
                                                  .length)
                                          : Container()),
                                  Flexible(
                                      flex: 1,
                                      fit: FlexFit.loose,
                                      child: sectionList[i]
                                                  .productList!
                                                  .length >=
                                              4
                                          ? productItem(
                                              i,
                                              3,
                                              false,
                                              sectionList[i].productList![3],
                                              1,
                                              sectionList[i]
                                                  .productList!
                                                  .length)
                                          : Container()),
                                ],
                              ),
                            ),
                          ],
                        ))
                    : sectionList[i].style == STYLE4
                        ? Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                    flex: 1,
                                    fit: FlexFit.loose,
                                    child: SizedBox(
                                        height: orient == Orientation.portrait
                                            ? deviceHeight! * 0.25
                                            : deviceHeight! * 0.5,
                                        child: sectionList[i]
                                                        .productList!
                                                        .length ==
                                                    1 ||
                                                sectionList[i]
                                                        .productList!
                                                        .length >
                                                    1
                                            ? productItem(
                                                i,
                                                0,
                                                false,
                                                sectionList[i].productList![0],
                                                1,
                                                sectionList[i]
                                                    .productList!
                                                    .length)
                                            : Container())),
                                SizedBox(
                                  height: orient == Orientation.portrait
                                      ? deviceHeight! * 0.2
                                      : deviceHeight! * 0.5,
                                  child: Row(
                                    children: [
                                      Flexible(
                                          flex: 1,
                                          fit: FlexFit.loose,
                                          child: sectionList[i]
                                                          .productList!
                                                          .length ==
                                                      2 ||
                                                  sectionList[i]
                                                          .productList!
                                                          .length >
                                                      2
                                              ? productItem(
                                                  i,
                                                  1,
                                                  true,
                                                  sectionList[i]
                                                      .productList![1],
                                                  1,
                                                  sectionList[i]
                                                      .productList!
                                                      .length)
                                              : Container()),
                                      Flexible(
                                          flex: 1,
                                          fit: FlexFit.loose,
                                          child: sectionList[i]
                                                          .productList!
                                                          .length ==
                                                      3 ||
                                                  sectionList[i]
                                                          .productList!
                                                          .length >
                                                      3
                                              ? productItem(
                                                  i,
                                                  2,
                                                  false,
                                                  sectionList[i]
                                                      .productList![2],
                                                  1,
                                                  sectionList[i]
                                                      .productList!
                                                      .length)
                                              : Container()),
                                    ],
                                  ),
                                ),
                              ],
                            ))
                        : Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: GridView.count(
                                padding:
                                    const EdgeInsetsDirectional.only(top: 5),
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                childAspectRatio: 1.2,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 0,
                                crossAxisSpacing: 0,
                                children: List.generate(
                                  sectionList[i].productList!.length < 6
                                      ? sectionList[i].productList!.length
                                      : 6,
                                  (index) {
                                    return productItem(
                                        i,
                                        index,
                                        index % 2 == 0 ? true : false,
                                        sectionList[i].productList![index],
                                        1,
                                        sectionList[i].productList!.length);
                                  },
                                )));
  }

  Widget productItem(
      int secPos, int index, bool pad, Product product, int from, int len) {
    if (len > index) {
      String? offPer;
      double price = double.parse(product.prVarientList![0].disPrice!);
      if (price == 0) {
        price = double.parse(product.prVarientList![0].price!);
      } else {
        double off = double.parse(product.prVarientList![0].price!) - price;
        offPer = ((off * 100) / double.parse(product.prVarientList![0].price!))
            .toStringAsFixed(3);
      }

      double width = deviceWidth! * 0.5;
      return Card(
        elevation: 0.0,

        margin: const EdgeInsetsDirectional.only(bottom: 2, end: 2),
        //end: pad ? 5 : 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(5),
                        topRight: Radius.circular(5)),
                    child: Hero(
                        transitionOnUserGestures: true,
                        tag: "$homeHero$index${product.id}$secPos",
                        child: networkImageCommon(product.image!, width, false,
                            height: double.maxFinite,
                            width: double.maxFinite))),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 10.0,
                  top: 5,
                ),
                child: Text(
                  product.name!,
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: Theme.of(context).colorScheme.lightBlack),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                  padding:
                      const EdgeInsetsDirectional.only(start: 10.0, top: 2),
                  child: Text(
                      product.isSalesOn == "1"
                          ? getPriceFormat(
                              context,
                              double.parse(
                                  product.prVarientList![0].saleFinalPrice!))!
                          : '${getPriceFormat(context, price)!} ',
                      style: TextStyle(
                          fontSize: 11.0,
                          color: Theme.of(context).colorScheme.fontColor,
                          fontWeight: FontWeight.bold))),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: 10.0, bottom: 8, top: 2),
                child: double.parse(product.prVarientList![0].disPrice!) != 0
                    ? Row(
                        children: <Widget>[
                          Text(
                            double.parse(product.prVarientList![0].disPrice!) !=
                                    0
                                ? getPriceFormat(
                                    context,
                                    double.parse(
                                        product.prVarientList![0].price!))!
                                : "",
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall!
                                .copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    letterSpacing: 0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .fontColor
                                        .withOpacity(0.6)),
                          ),
                          Flexible(
                            child: Text(
                                " | "
                                "-${product.isSalesOn == "1" ? double.parse(product.saleDis!).toStringAsFixed(2) : offPer}%",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall!
                                    .copyWith(
                                        color: colors.primary,
                                        letterSpacing: 0)),
                          ),
                        ],
                      )
                    : Container(
                        height: 5,
                      ),
              )
            ],
          ),
          onTap: () {
            Product model = product;
            currentHero = homeHero;
            Navigator.push(
              context,
              PageRouteBuilder(
                  // transitionDuration: Duration(milliseconds: 150),
                  pageBuilder: (_, __, ___) => ProductDetail(
                        secPos: secPos,
                        index: index,
                        list: false,
                        id: model.id!,

                        //  title: sectionList[secPos].title,
                      )),
            );
          },
        ),
      );
    } else {
      return Container();
    }
  }

  _section() {
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      itemCount: sectionList.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return _singleSection(index);
      },
    );
  }

  _catList() {
    return Container(
      height: 115,
      padding: const EdgeInsets.only(top: 10, left: 10),
      child: ListView.builder(
        itemCount: catList.length < 10 ? catList.length : 10,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container();
          } else {
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 17),
              child: InkWell(
                onTap: () async {
                  if (catList[index].subList == null ||
                      catList[index].subList!.isEmpty) {
                    await Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => ProductList(
                            name: catList[index].name,
                            id: catList[index].id,
                            tag: false,
                            fromSeller: false,
                          ),
                        ));
                  } else {
                    await Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => SubCategory(
                            title: catList[index].name!,
                            subList: catList[index].subList,
                          ),
                        ));
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                        padding: const EdgeInsetsDirectional.only(
                            bottom: 5.0, top: 8.0),
                        child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .fontColor
                                      .withOpacity(0.048),
                                  spreadRadius: 2,
                                  blurRadius: 13,
                                  offset: const Offset(
                                      0, 0), // changes position of shadow
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                                radius: 32.0,
                                backgroundColor: Colors
                                    .transparent /* Theme.of(context).colorScheme.white*/,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: networkImageCommon(
                                      catList[index].image!,
                                      50,
                                      width: double.maxFinite,
                                      height: double.maxFinite,
                                      false),
                                )
                                /*CachedNetworkImage(
                                            fadeInDuration: const Duration(
                                                milliseconds: 150),
                                            imageUrl: catList[index].image!,
                                            fit: BoxFit.fill,
                                            errorWidget:
                                                (context, error, stackTrace) =>
                                                    erroWidget(50),
                                            placeholder: (context, url) {
                                              return placeHolder(50);
                                            }),*/
                                ))),
                    SizedBox(
                      width: 50,
                      child: Text(
                        capitalize(catList[index].name!.toLowerCase()),
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: Theme.of(context).colorScheme.fontColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  List<T> map<T>(List list, Function handler) {
    List<T> result = [];
    for (var i = 0; i < list.length; i++) {
      result.add(handler(i, list[i]));
    }

    return result;
  }

  Future<void> callApi() async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      getSetting();
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }

    return;
  }

  void getSection() async {
    var dataJson = await readJsonAssets('assets/data/sections.json');
    var data = dataJson["data"];

    sectionList =
        (data as List).map((data) => SectionModel.fromJson(data)).toList();

    setState(() {});
  }

  void getSetting() async {
    try {
      String settingData = await DefaultAssetBundle.of(context)
          .loadString("assets/data/settings.json");
      final setRes = jsonDecode(settingData);

      var data = setRes["data"]["system_settings"][0];
      getSlider();
      getCat();
      getSection();
      //  getOfferImages();

      // proIds = (await db.getMostLike())!;
      // getMostLikePro();
      // proIds1 = (await db.getMostFav())!;
      //getMostFavPro();
      showPopUpOfferDialog();
      cartBtnList = true;
      refer = true;
      CUR_CURRENCY = 'VND ';
      RETURN_DAYS = data['max_product_return_days'];
      MAX_ITEMS = data["max_items_cart"];
      MIN_AMT = data['min_amount'];
      CUR_DEL_CHR = data['delivery_charge'];
      String? isVerion = data['is_version_system_on'];
      extendImg = data["expand_product_images"] == "1" ? true : false;
      String? del = data["area_wise_delivery_charge"];
      MIN_ALLOW_CART_AMT = data[MIN_CART_AMT];
      IS_LOCAL_PICKUP = data[LOCAL_PICKUP];
      ADMIN_ADDRESS = data[ADDRESS];
      ADMIN_LAT = data[LATITUDE];
      ADMIN_LONG = data[LONGITUDE];
      ADMIN_MOB = data[SUPPORT_NUM];
      IS_SHIPROCKET_ON =
          setRes["data"]["shipping_method"][0]["shiprocket_shipping_method"];
      IS_LOCAL_ON =
          setRes["data"]["shipping_method"][0]["local_shipping_method"];
      ALLOW_ATT_MEDIA = data[ALLOW_ATTACH];
    } on FormatException catch (e) {
      setSnackbar(e.message, context);
    }
  }

  Future<void> getMostLikePro() async {
    if (proIds.isNotEmpty) {
      _isNetworkAvail = await isNetworkAvailable();

      if (_isNetworkAvail) {
        try {
          var parameter = {"product_ids": proIds.join(',')};

          apiBaseHelper.postAPICall(getProductApi, parameter).then(
              (getdata) async {
            bool error = getdata["error"];
            if (!error) {
              var data = getdata["data"];

              List<Product> tempList =
                  (data as List).map((data) => Product.fromJson(data)).toList();
              mostLikeProList.clear();
              mostLikeProList.addAll(tempList);

              context.read<ProductProvider>().setProductList(mostLikeProList);
            }
            if (mounted) {
              setState(() {
                context.read<HomeProvider>().setMostLikeLoading(false);
              });
            }
          }, onError: (error) {
            setSnackbar(error.toString(), context);
          });
        } on TimeoutException catch (_) {
          setSnackbar(getTranslated(context, 'somethingMSg')!, context);
          context.read<HomeProvider>().setMostLikeLoading(false);
        }
      } else {
        if (mounted) {
          setState(() {
            _isNetworkAvail = false;
            context.read<HomeProvider>().setMostLikeLoading(false);
          });
        }
      }
    } else {
      context.read<ProductProvider>().setProductList([]);
      setState(() {
        context.read<HomeProvider>().setMostLikeLoading(false);
      });
    }
  }

  Future<void> getMostFavPro() async {
    if (proIds1.isNotEmpty) {
      _isNetworkAvail = await isNetworkAvailable();

      if (_isNetworkAvail) {
        try {
          var parameter = {"product_ids": proIds1.join(',')};

          apiBaseHelper.postAPICall(getProductApi, parameter).then(
              (getdata) async {
            bool error = getdata["error"];
            if (!error) {
              var data = getdata["data"];

              List<Product> tempList =
                  (data as List).map((data) => Product.fromJson(data)).toList();
              mostFavProList.clear();
              mostFavProList.addAll(tempList);
            }
            if (mounted) {
              setState(() {
                context.read<HomeProvider>().setMostLikeLoading(false);
              });
            }
          }, onError: (error) {
            setSnackbar(error.toString(), context);
          });
        } on TimeoutException catch (_) {
          setSnackbar(getTranslated(context, 'somethingMSg')!, context);
          context.read<HomeProvider>().setMostLikeLoading(false);
        }
      } else {
        if (mounted) {
          setState(() {
            _isNetworkAvail = false;
            context.read<HomeProvider>().setMostLikeLoading(false);
          });
        }
      }
    } else {
      context.read<CartProvider>().setCartlist([]);
      setState(() {
        context.read<HomeProvider>().setMostLikeLoading(false);
      });
    }
  }

  final _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  final Random _rnd = Random();

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  Future<void> generateReferral() async {
    try {
      String refer = getRandomString(8);

      //////

      Map parameter = {
        REFERCODE: refer,
      };

      apiBaseHelper.postAPICall(validateReferalApi, parameter).then((getdata) {
        bool error = getdata["error"];
        String? msg = getdata["message"];
        if (!error) {
          REFER_CODE = refer;

          Map parameter = {
            USER_ID: CUR_USERID,
            REFERCODE: refer,
          };

          apiBaseHelper.postAPICall(getUpdateUserApi, parameter);
        } else {
          if (count < 5) generateReferral();
          count++;
        }

        context.read<HomeProvider>().setSecLoading(false);
      }, onError: (error) {
        setSnackbar(error.toString(), context);
        context.read<HomeProvider>().setSecLoading(false);
      });
    } on FormatException catch (e) {
      setSnackbar(e.message, context);
    }
  }

  updateDailog() async {
    await dialogAnimate(context,
        StatefulBuilder(builder: (BuildContext context, StateSetter setStater) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(5.0))),
        title: Text(getTranslated(context, 'UPDATE_APP')!),
        content: Text(
          getTranslated(context, 'UPDATE_AVAIL')!,
          style: Theme.of(this.context)
              .textTheme
              .titleMedium!
              .copyWith(color: Theme.of(context).colorScheme.fontColor),
        ),
        actions: <Widget>[
          TextButton(
              child: Text(
                getTranslated(context, 'NO')!,
                style: Theme.of(this.context).textTheme.titleSmall!.copyWith(
                    color: Theme.of(context).colorScheme.lightBlack,
                    fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop(false);
              }),
          TextButton(
              child: Text(
                getTranslated(context, 'YES')!,
                style: Theme.of(this.context).textTheme.titleSmall!.copyWith(
                    color: Theme.of(context).colorScheme.fontColor,
                    fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                Navigator.of(context).pop(false);

                String url = '';
                if (Platform.isAndroid) {
                  url = androidLink + packageName;
                } else if (Platform.isIOS) {
                  url = iosLink;
                }

                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                } else {
                  throw 'Could not launch $url';
                }
              })
        ],
      );
    }));
  }

  Widget homeShimmer() {
    return SizedBox(
      width: double.infinity,
      child: Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.simmerBase,
        highlightColor: Theme.of(context).colorScheme.simmerHigh,
        child: SingleChildScrollView(
            child: Column(
          children: [
            catLoading(),
            sliderLoading(),
            sectionLoading(),
          ],
        )),
      ),
    );
  }

  Widget sliderLoading() {
    double width = deviceWidth!;
    double height = width / 2;
    return Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.simmerBase,
        highlightColor: Theme.of(context).colorScheme.simmerHigh,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: double.infinity,
          height: height,
          color: Theme.of(context).colorScheme.white,
        ));
  }

  Widget _buildImagePageItem(Model slider) {
    double height = deviceWidth! / 0.5;

    return InkWell(
      child: networkImageCommon(slider.image!, height, false,
          height: height, width: double.maxFinite)
      /* CachedNetworkImage(
          fadeInDuration: const Duration(milliseconds: 150),
          imageUrl: slider.image!,
          height: height,
          width: double.maxFinite,
          fit: BoxFit.fill,
          errorWidget: (context, error, stackTrace) => Image.asset(
                "assets/images/Placeholder_Rectangle.png",
                fit: BoxFit.fill,
                height: height,
                width: deviceWidth! / 2,
              ),
          placeholder: (BuildContext context, url) {
            return Image.asset(
              "${imagePath}Placeholder_Rectangle.png",
            );
          })*/
      ,
      onTap: () async {
        int curSlider = context.read<HomeProvider>().curSlider;
        print("value ${homeSliderList[curSlider].type}");
        if (homeSliderList[curSlider].type == "products") {
          Product? item = homeSliderList[curSlider].list;
          currentHero = homeHero;
          Navigator.push(
            context,
            PageRouteBuilder(
                pageBuilder: (_, __, ___) => ProductDetail(
                      secPos: 0,
                      index: 0,
                      list: true,
                      id: item!.id!,
                    )),
          );
        } else if (homeSliderList[curSlider].type == "categories") {
          Product item = homeSliderList[curSlider].list;
          if (item.subList!.isEmpty) {
            Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => ProductList(
                    name: item.name,
                    id: item.id,
                    tag: false,
                    fromSeller: false,
                  ),
                ));
          } else {
            Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => SubCategory(
                    title: item.name!,
                    subList: item.subList,
                  ),
                ));
          }
        } else if (homeSliderList[curSlider].type == "slider_url") {
          String url = homeSliderList[curSlider].urlLink.toString();
          try {
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            } else {
              throw 'Could not launch $url';
            }
          } catch (e) {
            throw 'Something went wrong';
          }
        }
      },
    );
  }

  Widget deliverLoading() {
    return Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.simmerBase,
        highlightColor: Theme.of(context).colorScheme.simmerHigh,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          width: double.infinity,
          height: 18.0,
          color: Theme.of(context).colorScheme.white,
        ));
  }

  Widget catLoading() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
                    .map((_) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.white,
                            shape: BoxShape.circle,
                          ),
                          width: 50.0,
                          height: 50.0,
                        ))
                    .toList()),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          width: double.infinity,
          height: 18.0,
          color: Theme.of(context).colorScheme.white,
        ),
      ],
    );
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
            context.read<HomeProvider>().setCatLoading(true);
            context.read<HomeProvider>().setSecLoading(true);
            context.read<HomeProvider>().setOfferLoading(true);
            context.read<HomeProvider>().setMostLikeLoading(true);
            context.read<HomeProvider>().setSliderLoading(true);
            _playAnimation();

            Future.delayed(const Duration(seconds: 2)).then((_) async {
              _isNetworkAvail = await isNetworkAvailable();
              if (_isNetworkAvail) {
                if (mounted) {
                  setState(() {
                    _isNetworkAvail = true;
                  });
                }
                callApi();
              } else {
                await buttonController.reverse();
                if (mounted) setState(() {});
              }
            });
          },
        )
      ]),
    );
  }

  _deliverPincode() {
    // String curpin = context.read<UserProvider>().curPincode;
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      color: Theme.of(context).colorScheme.lightWhite,
      child: ListTile(
        dense: true,
        minLeadingWidth: 10,
        leading: const Icon(
          Icons.location_pin,
        ),
        title: Text(
            '2/4/6A Lê Thúc Hoạch, phường Phú Thọ Hòa, quận Tân Phú, tp. Hồ Chí Minh',
            style: TextStyle(color: Theme.of(context).colorScheme.fontColor)),
        trailing: const Icon(Icons.keyboard_arrow_right),
      ),
    );
  }

  _getSearchBar() {
    return InkWell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: 38,
          child: TextField(
            enabled: false,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
                contentPadding: const EdgeInsets.fromLTRB(15.0, 5.0, 0, 5.0),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(50.0),
                  ),
                  borderSide: BorderSide(
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                isDense: true,
                hintText: getTranslated(context, 'searchHint'),
                hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.fontColor,
                    ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SvgPicture.asset(
                    'assets/images/search.svg',
                    color: colors.primary,
                  ),
                ),
                fillColor: Theme.of(context).colorScheme.lightWhite,
                filled: true),
          ),
        ),
      ),
      onTap: () async {
        await Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => const Search(),
            ));
        if (mounted) setState(() {});
      },
    );
  }

  void _pincodeCheck() {
    showModalBottomSheet<dynamic>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25), topRight: Radius.circular(25))),
        builder: (builder) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9),
              child: ListView(shrinkWrap: true, children: [
                Padding(
                    padding: const EdgeInsets.only(
                        left: 20.0, right: 20, bottom: 40, top: 30),
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: Form(
                          key: _formkey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Icon(Icons.close),
                                ),
                              ),
                              TextFormField(
                                keyboardType: TextInputType.number,
                                textCapitalization: TextCapitalization.words,
                                validator: (val) => validatePincode(val!,
                                    getTranslated(context, 'PIN_REQUIRED')),
                                onSaved: (String? value) {
                                  context
                                      .read<UserProvider>()
                                      .setPincode(value!);
                                },
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall!
                                    .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .fontColor),
                                decoration: InputDecoration(
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.location_on),
                                  hintText:
                                      getTranslated(context, 'PINCODEHINT_LBL'),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      margin: const EdgeInsetsDirectional.only(
                                          start: 20),
                                      width: deviceWidth! * 0.35,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          context
                                              .read<UserProvider>()
                                              .setPincode('');

                                          context
                                              .read<HomeProvider>()
                                              .setSecLoading(true);
                                          getSection();
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                            getTranslated(context, 'All')!),
                                      ),
                                    ),
                                    const Spacer(),
                                    SimBtn(
                                        width: 0.35,
                                        height: 35,
                                        title: getTranslated(context, 'APPLY'),
                                        onBtnSelected: () async {
                                          if (validateAndSave()) {
                                            // validatePin(curPin);
                                            context
                                                .read<HomeProvider>()
                                                .setSecLoading(true);
                                            getSection();

                                            Navigator.pop(context);
                                          }
                                        }),
                                  ],
                                ),
                              ),
                            ],
                          )),
                    ))
              ]),
            );
            //});
          });
        });
  }

  bool validateAndSave() {
    final form = _formkey.currentState!;

    form.save();
    if (form.validate()) {
      return true;
    }
    return false;
  }

  Future<void> _playAnimation() async {
    try {
      await buttonController.forward();
    } on TickerCanceled {}
  }

  Future<dynamic> readJsonAssets(String pathJs) async {
    final String response = await rootBundle.loadString(pathJs);
    final data = await json.decode(response);
    return data;
  }

  void getSlider() async {
    try {
      var jsonData = await readJsonAssets('assets/data/slides.json');

      var data = jsonData["data"];

      homeSliderList =
          (data as List).map((data) => Model.fromSlider(data)).toList();

      pages = homeSliderList.map((slider) {
        return _buildImagePageItem(slider);
      }).toList();

      setState(() {});
    } on FormatException catch (e) {
      setSnackbar(e.message, context);
    }
  }

  void getCat() async {
    try {
      Map parameter = {
        CAT_FILTER: "false",
      };
      String dataJs = await DefaultAssetBundle.of(context)
          .loadString("assets/data/categories.json");
      final catRes = jsonDecode(dataJs);

      var data = catRes["data"];

      catList = (data as List).map((data) => Product.fromCat(data)).toList();

      if (catRes.containsKey("popular_categories")) {
        var data = catRes["popular_categories"];
        popularList =
            (data as List).map((data) => Product.fromCat(data)).toList();

        if (popularList.isNotEmpty) {
          Product pop = Product.popular("Popular", "${imagePath}popular.svg");
          catList.insert(0, pop);
          context.read<CategoryProvider>().setSubList(popularList);
        }
      }

      setState(() {});
    } on FormatException catch (e) {
      setSnackbar(e.message, context);
    }
  }

  sectionLoading() {
    return Column(
        children: [0, 1, 2, 3, 4]
            .map((_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                                margin: const EdgeInsets.only(bottom: 40),
                                decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.white,
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20)))),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 5),
                                width: double.infinity,
                                height: 18.0,
                                color: Theme.of(context).colorScheme.white,
                              ),
                              GridView.count(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  childAspectRatio: 1.0,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 5,
                                  crossAxisSpacing: 5,
                                  children: List.generate(
                                    4,
                                    (index) {
                                      return Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color:
                                            Theme.of(context).colorScheme.white,
                                      );
                                    },
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    sliderLoading()
                    //offerImages.length > index ? _getOfferImage(index) : Container(),
                  ],
                ))
            .toList());
  }

  void appMaintenanceDialog() async {
    await dialogAnimate(context,
        StatefulBuilder(builder: (BuildContext context, StateSetter setStater) {
      return WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: AlertDialog(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5.0))),
          title: Text(
            getTranslated(context, 'APP_MAINTENANCE')!,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.fontColor,
                fontWeight: FontWeight.normal,
                fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                child: Lottie.asset('assets/animation/maintenance.json'),
              ),
              const SizedBox(
                height: 25,
              ),
              Text(
                IS_APP_MAINTENANCE_MESSAGE != ''
                    ? IS_APP_MAINTENANCE_MESSAGE!
                    : getTranslated(context, 'MAINTENANCE_DEFAULT_MESSAGE')!,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.fontColor,
                    fontWeight: FontWeight.normal,
                    fontSize: 12),
              )
            ],
          ),
        ),
      );
    }));
  }

  void showPopUpOfferDialog() async {
    await dialogAnimate(context,
        StatefulBuilder(builder: (BuildContext context, StateSetter setStater) {
      return Dialog(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(5.0))),
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        child: InkWell(
          onTap: () {
            popUpOfferImageClick();
          },
          child: Container(
            margin: const EdgeInsets.only(left: 0.0, right: 0.0),
            child: Stack(
              children: <Widget>[
                Container(
                    /*  padding: const EdgeInsets.only(
                      top: 18.0,
                    ),*/
                    margin:
                        const EdgeInsets.only(top: 13.0, right: 8.0, left: 8.0),
         
                    decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(15.0),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: (Theme.of(context).colorScheme.white)
                                .withOpacity(0.5),
                            blurRadius: 0.0,
                            offset: const Offset(0.0, 0.0),
                          ),
                        ]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15.0),
                      child: Image.asset('assets/images/offerpopup.png',
                          width: MediaQuery.of(context).size.width,
                          fit: BoxFit.contain),
                    )),
                Positioned(
                  right: 0.0,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Align(
                      alignment: Alignment.topRight,
                      child: CircleAvatar(
                        radius: 14.0,
                        backgroundColor: (Theme.of(context).colorScheme.white)
                            .withOpacity(0.7),
                        child: const Icon(Icons.close, color: colors.red),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom:0,
                  left: MediaQuery.of(context).size.width / 2 - 100,
                  child: ElevatedButton(onPressed: (){
                    Get.to(()=> const Login());
                  }, child: const Text('Go to Login'), style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                    minimumSize: Size(120, 35)
                  ),),
                )
              ],
            ),
          ),
        ),
      );
    }));
  }

  popUpOfferImageClick() async {
    Navigator.pop(context);
    if (popUpOffer.type == "products") {
      String id = popUpOffer.data![0].id!;
      currentHero = homeHero;
      Navigator.push(
        context,
        PageRouteBuilder(
            //transitionDuration: Duration(seconds: 1),
            pageBuilder: (_, __, ___) => ProductDetail(
                  secPos: 0, index: 0, list: true, id: id,

                  //  title: sectionList[secPos].title,
                )),
      );
    } else if (popUpOffer.type == "categories") {
      Product item = popUpOffer.data!;
      if (item.subList == null || item.subList!.isEmpty) {
        Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ProductList(
                name: item.name,
                id: item.id,
                tag: false,
                fromSeller: false,
                maxDis: popUpOffer.maxDiscount,
                minDis: popUpOffer.minDiscount,
              ),
            ));
      } else {
        Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => SubCategory(
                title: item.name!,
                subList: item.subList,
                maxDis: popUpOffer.maxDiscount,
                minDis: popUpOffer.minDiscount,
              ),
            ));
      }
    } else if (popUpOffer.type == "all_products") {
      Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ProductList(
              tag: false,
              fromSeller: false,
              maxDis: popUpOffer.maxDiscount,
              minDis: popUpOffer.minDiscount,
            ),
          ));
    } else if (popUpOffer.type == "brand") {
      Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ProductList(
              tag: false,
              fromSeller: false,
              maxDis: popUpOffer.maxDiscount,
              minDis: popUpOffer.minDiscount,
              brandId: popUpOffer.typeId,
              name: popUpOffer.data![0].name!,
            ),
          ));
    } else if (popUpOffer.type == "offer_url") {
      String url = popUpOffer.urlLink.toString();
      try {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $url';
        }
      } catch (e) {
        throw 'Something went wrong';
      }
    }
  }
}
