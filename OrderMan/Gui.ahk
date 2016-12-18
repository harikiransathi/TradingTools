/*
  Copyright (C) 2015  SpiffSpaceman

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>
*/

initGUI(){
	global
	
	isABPick 				  := false												// Initialze GUI global vars
	ORDER_TYPE_GUI_LIMIT	  := "LIM"
	ORDER_TYPE_GUI_MARKET	  := "M"
	ORDER_TYPE_GUI_SL_LIMIT	  := "SL"
	ORDER_TYPE_GUI_SL_MARKET  := "SLM"
	SelectedScripText 		  := ""													// To avoid uninitialized error
}

createGUI(){
	global Qty, TargetQty, EntryPrice, StopPrice, TargetPrice, Direction, CurrentResult, TargetResult, BtnOrder, BtnUpdate, BtnLink, BtnUnlink, BtnCancel, EntryStatus, StopStatus, TargetStatus, LastWindowPosition, EntryOrderType, EntryUpDown, StopUpDown, TargetUpDown, EntryText, AddText, BtnAdd, SelectedScripText, ScripList, PriceStatus
	
	SetFormat, FloatFast, 0.2

	initGUI()
		
	Gui, 1:New, +AlwaysOnTop +Resize, OrderMan

// Column 1
	Gui, 1:Add, DropDownList, vSelectedScripText gonScripChange w100 Choose1, %ScripList%	
// row 1
	Gui, 1:Add, Text, vPriceStatus w120 x+m

// Column 1 
	Gui, 1:Add, ListBox, vDirection gonDirectionChange h30 w20 xm Choose1, B|S		// xm - start from first column ( x coordinate = default margin )
	Gui, 1:Add, DropDownList, vEntryOrderType w45 Choose1, LIM|SL|SLM|M 			// Entry Type
		
// Column 2	- But below Scrip change Dropdown
	Gui, 1:Add, Text, vEntryText ym+25 x+m, Entry
	Gui, 1:Add, Text, vAddText xp+0 yp+0, Add
	Gui, 1:Add, Text, gstopClick, Stop
	Gui, 1:Add, Text, gTargetClick, Target

// Column 3	
	Gui, 1:Add, Edit, vEntryPrice  w55    gonEntryPriceChange ym+25 x+m
	Gui, 1:Add, Edit, vStopPrice   w55    gonStopPriceChange
	Gui, 1:Add, Edit, vTargetPrice w55    gupdateCurrentResult
		
	Gui, 1:Add, Button, gonNew vBtnOrder xp-35 y+m, New								// New or Update
	Gui, 1:Add, Button, gonUpdate vBtnUpdate  xp+0 yp+0, Update	

	Gui, 1:Add, Button, gopenLinkOrdersGUI vBtnLink x+5, Link						// Link or Unlink
	Gui, 1:Add, Button, gonUnlink vBtnUnlink xp+0 yp+0, Unlink		
	
// Column 4 
	Gui, 1:Add, UpDown, vEntryUpDown  gOnEntryUpDown   Range0-1 -16 hp-2 x+0 ym+25
	Gui, 1:Add, UpDown, vStopUpDown   gOnStopUpDown    Range0-1 -16 hp
	Gui, 1:Add, UpDown, vTargetUpDown gOnTargetUpDown  Range0-1 -16 hp

// Column 5
	Gui, 1:Add, Edit, vQty w30 ym+25 x+m
	Gui, 1:Add, Edit, vTargetQty w30  y+32
	Gui, 1:Add, Button, gonCancel vBtnCancel y+m, Cancel		 					// Add or Cancel button	
	Gui, 1:Add, Button, gonAdd vBtnAdd xp+0 yp+0, Add

// Column 6
	Gui, 1:Add, Text, vCurrentResult  w38 ym+53 x+m
	Gui, 1:Add, Text, vTargetResult   w38

// Column 7
	Gui, 1:Add, Text, ym+25 vEntryStatus
	Gui, 1:Add, Text, vStopStatus	
	Gui, 1:Add, Text, vTargetStatus
		
	Gui, 1:Add, StatusBar, gstatusBarClick, 										// Status Bar - Shows link order Numbers. Double click to link manually
	
	if( LastWindowPosition != "ERROR" && LastWindowPosition != "" )
		Gui, 1:Show, AutoSize NoActivate %LastWindowPosition%
	else
		Gui, 1:Show, AutoSize NoActivate

	onScripChange()																	// Loads default scrip ini and initializes GUI values to defaults 
	setDefaultEntryOrderType()
	initalizeListViewVars()
	setDefaultFocus()

	return
}

/* Link Button GUI
*/
openLinkOrdersGUI(){	
	
	global listViewFields, LinkOrdersSelectedDirection, LinkedScripText, ScripList
	
	LinkedScripText := ""
	
	Gui, 2:New, +AlwaysOnTop, Link Orders

	Gui, 2:font, bold
	Gui, 2:Add, Text,, Select Entry Order
	Gui, 2:font
	Gui, 2:Add, ListView, w600, % listViewFields
	
	Gui, 2:Add, Radio, vLinkOrdersSelectedDirection gonLinkOrdersDirectionSelect Checked, Long
	Gui, 2:Add, Radio, gonLinkOrdersDirectionSelect xp+60 yp, Short
	Gui, 2:Add, DropDownList, vLinkedScripText x+15 w100, %ScripList%

	// Column 2

	Gui, 2:font, bold
	Gui, 2:Add, Text, ym , Select Stop, Target Order
	Gui, 2:font	
	Gui, 2:Add, ListView, w600 SortDesc,  % listViewFields
	
	onLinkOrdersDirectionSelect()
	
	Gui, 2:Add, Button, Default glinkOrdersSubmit, Link Orders
	Gui, 2:Show, AutoSize	
}

/* Fills up Entry/Stop ListViews in Link Orders GUI based on input Direction
*/
onLinkOrdersDirectionSelect(){
	global  controlObj, orderbookObj, LinkOrdersSelectedDirection
	
	Gui, 2:Submit, NoHide

	entryDirection := LinkOrdersSelectedDirection == 1 ? controlObj.ORDER_DIRECTION_BUY  : controlObj.ORDER_DIRECTION_SELL		// Long Selected then Entry is Buy Order
	stopDirection  := LinkOrdersSelectedDirection == 1 ? controlObj.ORDER_DIRECTION_SELL : controlObj.ORDER_DIRECTION_BUY		// Long Selected then Stop  is Sell Order
	
	orderbookObj.read()
	
	Gui, 2:ListView, SysListView321						// Entry Listview
	LV_Delete()											// Delete All Rows
	Loop, % orderbookObj.OpenOrders.size {				// Show Open Orders + Closed Orders with status Complete in Selected Direction
		o := orderbookObj.OpenOrders[A_Index]
		if( o.buySell == entryDirection )
			addOrderRow( o, "Open" )
	}
	Loop, % orderbookObj.CompletedOrders.size {
		o := orderbookObj.CompletedOrders[A_Index]
		if( o.status == controlObj.ORDER_STATUS_COMPLETE && o.buySell == entryDirection )
			addOrderRow(o, "Executed")
	}
	if(  LV_GetCount() > 0  )
		LV_ModifyCol()									// Show All text
	
	
	
	Gui, 2:ListView, SysListView322						// Stop Listview
	LV_Delete()											// Delete All Rows
	Loop, % orderbookObj.OpenOrders.size {				// Open Stop and target
		o :=  orderbookObj.OpenOrders[A_Index]
		if( (o.orderType == controlObj.ORDER_TYPE_SL_MARKET || o.orderType == controlObj.ORDER_TYPE_SL_LIMIT)  && o.buySell == stopDirection)
			addOrderRow( o, "Stop" )					// filter: Open + SL/SLM + stop direction
		if( o.orderType == controlObj.ORDER_TYPE_LIMIT && o.buySell == stopDirection)
			addOrderRow( o, "Target" )					
	}
	Loop, % orderbookObj.CompletedOrders.size {			// Completed targets
		o :=  orderbookObj.CompletedOrders[A_Index]
		if( o.orderType == controlObj.ORDER_TYPE_LIMIT && o.buySell == stopDirection && o.isComplete() )
			addOrderRow( o, "Target-Executed" )
	}
	if(  LV_GetCount() > 0  )
		LV_ModifyCol()	

	Gui, 2:Show, AutoSize
}

/* Linked Order Status GUI
*/
openStatusGUI(){
	global orderbookObj, contextObj, listViewFields
	
	orderbookObj.read()	
	
	Gui, 3:New, +AlwaysOnTop, Linked Orders
	Gui, 3:font, bold
	Gui, 3:Add, Text,, Linked Order Details
	Gui, 3:font
	
	Gui, 3:Add, ListView, w600 -Multi SortDesc,  % listViewFields
	
	trade := contextObj.getCurrentTrade()
	addOrderRow( trade.newEntryOrder.getOrderDetails(), "Entry(Open)" )
	addOrderRow( trade.stopOrder.getOrderDetails(),     "Stop(Open)" )
	addOrderRow( trade.target.getOpenOrder().getOrderDetails(),   "Target(Open)" )
	
	For index, value in trade.executedEntryOrderList{
		addOrderRow( value.getOrderDetails(), "Entry(Executed)" )
	}
	For index, value in trade.target.executedOrderList{
		addOrderRow( value.getOrderDetails(), "Target(Executed)" )
	}
	
	if(  LV_GetCount() > 0  )
		LV_ModifyCol()								// Show All text
	
	Gui, 3:Show, AutoSize
}

/* Sets Position status if Stop hits
   Sets Position status if target hits
*/
updateCurrentResult(){
	global
	
	Gui, 1:Submit, NoHide
	
	CurrentResult := Direction == "B" ? StopPrice-EntryPrice : EntryPrice-StopPrice
	TargetResult  := TargetPrice == 0 ? "" : (Direction == "B" ? TargetPrice-EntryPrice : EntryPrice-TargetPrice)
	
	GuiControl, 1:Text, CurrentResult, %CurrentResult%	
	GuiControl, 1:Text, TargetResult,  %TargetResult%	
}

/* Sets Stop price using default Stop size 
*/
setDefaultStop(){
	global
		
	Gui, 1:Submit, NoHide			
	StopPrice :=  Direction == "B" ? EntryPrice-DefaultStopSize : EntryPrice+DefaultStopSize		
	GuiControl, 1:Text, StopPrice, %StopPrice%
	
	updateCurrentResult()
}

/* Sets Target price using default Target size 
*/
setDefaultTarget(){
	global
		
	Gui, 1:Submit, NoHide			
	TargetPrice :=  Direction == "B" ? EntryPrice+DefaultTargetSize : EntryPrice-DefaultTargetSize		
	GuiControl, 1:Text, TargetPrice, %TargetPrice%
	
	updateCurrentResult()
}




//   -- GUI Updates --- 

/*	Update status bar, GUI controls state and Timer state based on order status
*/
updateStatus(){
	global contextObj, orderbookObj, EntryPrice, StopPrice
	
	trade 			  := contextObj.getCurrentTrade()
	trade.reload()
	
	entryOrderDetails := trade.newEntryOrder.getOrderDetails()
	stopOrderDetails  := trade.stopOrder.getOrderDetails()
	targetOrderDetails:= trade.target.getOpenOrder().getOrderDetails()

	entryLinked 	  := trade.isNewEntryLinked()
	stopLinked		  := trade.isStopLinked()
	anyLinked		  := entryLinked || stopLinked 
	targetLinked	  := trade.isTargetLinked()
	entryOpen		  := trade.isEntryOpen()
	isStopPending 	  := trade.isStopPending										// Is Stop waiting for Entry to trigger
	stopOpen		  := trade.isStopOpen()	 || isStopPending	
	isEntryClosed	  := trade.isEntryClosed()
	isStopClosed	  := trade.isStopClosed()
	positionSize	  := trade.positionSize
	openSize		  := entryLinked ? entryOrderDetails.totalQty : 0
	isEntered		  := positionSize > 0
	
	GuiControl, % isEntered ? "1:Hide" : "1:Show", EntryText						// Show Add Label once Initial Entry order is successful
	GuiControl, % isEntered ? "1:Show" : "1:Hide", AddText
	
	GuiControl, % anyLinked ? "1:Disable" : "1:Enable", SelectedScripText			// Disable Scrip combobox if orders Linked
	GuiControl, % anyLinked ? "1:Disable" : "1:Enable", Direction					// Disable Direction if orders Linked
	GuiControl, % anyLinked ? "1:Show"    : "1:Hide",   BtnUnlink					// Show Order if unlinked. If orders links show Unlink button instead
	GuiControl, % anyLinked	? "1:Hide"    : "1:Show",   BtnLink						// Show Link if not linked
	GuiControl, % anyLinked ? "1:Hide"    : "1:Show",   BtnOrder		

	GuiControl, % entryOpen    || stopOpen  ? "1:Show"  : "1:Hide", BtnUpdate		// Show Update only if atleast one linked order is open
	GuiControl, % entryOpen   			    ? "1:Show"  : "1:Hide", BtnCancel		// Show Cancel Button if Entry Order is linked and open	
	GuiControl, % isEntered && !entryLinked ? "1:Show"  : "1:Hide", BtnAdd			// Show Add if already have a position and dont have add entry order linked
	
	GuiControl, % !entryLinked || entryOpen ? "1:Enable"  : "1:Disable", EntryPrice	// Enable Price entry for new orders or for linked open orders
	GuiControl, % !stopLinked  || stopOpen  ? "1:Enable"  : "1:Disable", StopPrice

	status := ""
	if( entryLinked ){																// Set Status if Linked
		shortStatus	:= getOrderShortStatus( entryOrderDetails.status )		
		status 		:= openSize > 0 ?  shortStatus . "(" . openSize . ")"   :  shortStatus
	}
	setOrderStatus( "EntryStatus", status )
	
	status := ""
	if( stopLinked  ){		
		shortStatus	:= getOrderShortStatus( stopOrderDetails.status )
		status 		:= shortStatus . " (" . stopOrderDetails.totalQty . ")"
	}
	if( isStopPending ){
		pendingstatus := "P" . "(" . openSize . ")"
		status 		  := pendingstatus . "  " .  status
	}
	setOrderStatus( "StopStatus", status )
	
	status := "" 
	targetOpenSize := 0
	if( targetLinked  ){
		shortStatus		:= getOrderShortStatus( targetOrderDetails.status )
		targetOpenSize  := trade.target.getOpenOrder().getOpenQty()
		status 			:= shortStatus . " (" . targetOpenSize . ")"
	}
	if( trade.target.getPrice() > 0  && entryOpen ){
		targetSize	   		:= trade.target.getGUIQty() - targetOpenSize					// Balance Qty Available for Pending
		pendingTargetSize   := targetSize > openSize ? openSize : targetSize				// Pending target Order size is not more than Open Entry Order size
		if( pendingTargetSize > 0  ){
			pendingstatus  		:= "P" . "(" . pendingTargetSize . ")"
			status 		   		:= pendingstatus . "  " .  status
		}
	}
	setOrderStatus( "TargetStatus", status )
	
	isTimerActive := (entryLinked || stopLinked) && ! (isEntryClosed && isStopClosed) 		// If order linked, start tracking orderbook. But stop if both closed
	isTimerActive := isTimerActive ?  toggleStatusTracker( "on" ) : toggleStatusTracker( "off" )	
	timeStatus    := isTimerActive ? "ON" : "OFF"
			
	SB_SetText( "Timer: " . timeStatus . "  Open Position: " . positionSize . ". Unfilled: " . openSize )

	Gui, 1:Show, AutoSize NA
}

/*	Sets Entry/Stop/Target status 
*/
setOrderStatus(  statusGuiId, status  ){
	if( status == "" ){
		GuiControl, 1:Text, %statusGuiId%, 
		GuiControl, 1:Move, %statusGuiId%, w1
		return
	}
	
	length := StrLen(status)
	width  := length <= 12 ? "w50" : ( length <= 20 ? "w75" : "w125")
	
	GuiControl, 1:Text, %statusGuiId%, % status
	GuiControl, 1:Move, %statusGuiId%, % width		
}

/*  Loads Trade from TradeClass>OrderClass>InputClass into GUI
	Used when linking to existing orders
*/
loadTradeInputToGui(){
	global contextObj

	trade  		:= contextObj.getCurrentTrade()
	scripAlias	:= trade.scrip.alias
	entry  		:= trade.newEntryOrder
	entryInput  := entry.getInput()
	stop  		:= trade.stopOrder
	target	    := trade.target

	setSelectedScrip( scripAlias )
	setGUIValues( entryInput.qty, entry.getPrice(), stop.getPrice(), target.getPrice(),  target.getGUIQty(), entryInput.direction, entryInput.orderType  )
	updateCurrentResult()
}

setGUIValues( inQty, inEntry, inStop, inTargetPrice, inTargetQty, inDirection, inEntryOrderType  ){
	
	setQty( inQty )
	setEntryPrice( inEntry, inEntry )
	setStopPrice( inStop, inStop )
	setDirection( inDirection )	
	selectEntryOrderType( inEntryOrderType )
	setTargetPrice( inTargetPrice )
	setTargetQty(inTargetQty)
	
	updateStatus()	
}

setSelectedScrip( alias ){
	global SelectedScripText	
	
	oldScrip		  := SelectedScripText
	SelectedScripText := alias
	GuiControl, 1:ChooseString, SelectedScripText,  %SelectedScripText%
	
	Gui, 1:Submit, NoHide
	
	if( alias !=""  &&  oldScrip!=SelectedScripText  ){
		loadScripSettings()																// onScripChange() is not called by above even though dropdown is changed. So load manually
	}
}

setPriceStatus( inPrice ){
	global PriceStatus
	PriceStatus := inPrice
	GuiControl, 1:Text, PriceStatus,  %PriceStatus%
}

setQty( inQty ){
	global Qty
	Qty := inQty
	GuiControl, 1:Text, Qty,  %Qty%
}

setTargetQty( inQty ){
	global TargetQty
	TargetQty := inQty
	GuiControl, 1:Text, TargetQty,  %TargetQty%
}

setDefaultQty(){
	global DefaultQty
	setQty( DefaultQty )
}

/* EntryPriceActual should contain the original values taken from AB
*/
setEntryPrice( inEntry, inEntryPriceActual){
	global EntryPrice, EntryPriceActual
	
	EntryPrice 		 := inEntry
	EntryPriceActual := inEntryPriceActual
	GuiControl, 1:Text, EntryPrice,  %EntryPrice%
}

/* StopPriceActual should contain the original values taken from AB
*/
setStopPrice( inStop, inStopPriceActual ){
	global StopPrice, StopPriceActual

	StopPrice 		:= inStop
	StopPriceActual := inStopPriceActual
	GuiControl, 1:Text, StopPrice, %StopPrice%
}

setTargetPrice( inTarget ){
	global TargetPrice
	
	TargetPrice := inTarget	
	
	GuiControl, 1:Text, TargetPrice, %TargetPrice%
}

setDirection( inDirection ){
	global Direction
	Direction := inDirection
	GuiControl, 1:ChooseString, Direction,  %Direction%
	onDirectionChange()
}

selectEntryOrderType( inEntryOrderType ){	
	global EntryOrderType	
	
	if( inEntryOrderType != "" ){
		EntryOrderType := inEntryOrderType
		GuiControl, 1:ChooseString, EntryOrderType,  %EntryOrderType%
	}
}

setDefaultEntryOrderType(){
	global DefaultEntryOrderType
	selectEntryOrderType( DefaultEntryOrderType )
}

setDefaultFocus(){
	ControlFocus, Edit2, OrderMan, Entry											// Set Focus on Entry Price
}

// -- GUI Helpers --- 

/* Map order status to short code for GUI
*/
getOrderShortStatus( status ){
	global
	
	if( status == controlObj.ORDER_STATUS_OPEN )
		return "O"
	else if( status == controlObj.ORDER_STATUS_TRIGGER_PENDING )
		return "O-TP"
	else if( status == controlObj.ORDER_STATUS_COMPLETE )
		return "C"
	else if( status == controlObj.ORDER_STATUS_REJECTED )
		return "R"
	else if( status == controlObj.ORDER_STATUS_CANCELLED )
		return "CAN"
	else
		return status
}

/* Headers for Order Listviews
*/
initalizeListViewVars(){
	global
	
	listViewFields 	   	         := "Type|Scrip|Status|OrderType|Buy/Sell|Qty|PendingQty|Price|Trigger|Average|Order No|Time"
	listViewOrderIDPosition   	 := 11
	listViewOrderStatusPosition  := 3
	listViewOrderTypePosition	 := 4
}

/* Adds row to list View
*/
addOrderRow( o, type ) {
	if( IsObject(o) )
		LV_Add("", type, o.tradingSymbol, o.status, o.orderType, o.buySell, o.totalQty, o.pendingQty, o.price, o.triggerPrice, o.averagePrice, o.nowOrderNo, o.nowUpdateTime )
}


GuiClose:
	saveLastPosition()
	ExitApp
