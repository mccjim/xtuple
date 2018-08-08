-- Group: ledgercontrol2
-- Name:  detail
-- Notes: query to log ledger control values

SELECT ledger, vseq, 
coalesce(glamount, 0) AS glamount,
coalesce(subledger, 0) AS subledger,
CASE WHEN ledger IN ('Payables', 'Uninvoiced Receipts') THEN
coalesce(glamount, 0) - coalesce(subledger, 0) ELSE coalesce(subledger, 0) - coalesce(glamount, 0) END  AS varamt,
CASE WHEN glamount != subledger THEN 'emphasis'
     END AS qtforegroundrole,
vseq AS xtindentrole
 FROM
(

--        Payables
SELECT 'Payables' AS ledger, 0 AS vseq,  sum(trialbal_ending) AS glamount,
(SELECT 
ROUND(SUM( CASE WHEN apopen_doctype IN ('V', 'D') THEN (apopen_amount - apopen_paid)/apopen_curr_rate
ELSE (apopen_amount - apopen_paid)/apopen_curr_rate * -1 END),2) 
  FROM apopen WHERE apopen_open AND apopen_docdate <= period_end) AS subledger

   FROM trialbal
JOIN period ON current_date BETWEEN period_start AND period_end AND trialbal_period_id = period_id
 WHERE  trialbal_accnt_id IN (SELECT apaccnt_ap_accnt_id FROM apaccnt)
 GROUP BY ledger, subledger

UNION ALL

--        Payables detail
SELECT formatglaccountlong(trialbal_accnt_id) AS ledger, 1 AS vseq,  sum(trialbal_ending) AS glamount,
(SELECT 
ROUND(SUM( CASE WHEN apopen_doctype IN ('V', 'D') THEN (apopen_amount - apopen_paid)/apopen_curr_rate
ELSE (apopen_amount - apopen_paid)/apopen_curr_rate * -1 END),2) 
  FROM apopen 

WHERE apopen_open 
AND findapaccount(apopen_vend_id) = trialbal_accnt_id
AND apopen_docdate <= period_end) AS subledger

   FROM trialbal
JOIN period ON current_date BETWEEN period_start AND period_end AND trialbal_period_id = period_id
 WHERE  trialbal_accnt_id IN (SELECT apaccnt_ap_accnt_id FROM apaccnt)
 GROUP BY ledger, subledger


UNION ALL
-- Uninvoiced Receipts
SELECT 'Uninvoiced Receipts' AS ledger, 0 AS vseq, sum(trialbal_ending) AS glamount,

(SELECT COALESCE(
SUM( CASE WHEN recv_order_type = 'PO' THEN
ROUND(recv_qty * recv_recvcost,2)
ELSE
ROUND(recv_qty * recv_recvcost *-1,2)END), 0) 
  FROM recv 

  WHERE recv_invoiced = false AND recv_vohead_id IS NULL AND recv_posted AND recv_order_type = 'PO') -
(SELECT 
COALESCE(SUM( poreject_value),0)
  FROM poreject WHERE poreject_invoiced = false AND poreject_vohead_id IS NULL AND poreject_posted) 

  AS subledger

  FROM trialbal 
 WHERE trialbal_period_id  = (SELECT period_id FROM period WHERE current_date BETWEEN period_start AND period_end)
 AND trialbal_accnt_id IN (SELECT costcat_liability_accnt_id FROM costcat 
		UNION ALL SELECT expcat_liability_accnt_id FROM expcat)
 GROUP BY ledger, subledger

UNION ALL
-- Uninvoiced Receipts detail
SELECT formatglaccountlong(trialbal_accnt_id) AS ledger, 1 AS vseq, (trialbal_ending) AS glamount,

(SELECT COALESCE(
SUM( CASE WHEN recv_order_type = 'PO' THEN
ROUND(recv_qty * recv_recvcost,2)
ELSE
ROUND(recv_qty * recv_recvcost *-1,2)END), 0) 
  FROM recv
  JOIN poitem ON recv_orderitem_id = poitem_id
LEFT JOIN expcat ON poitem_expcat_id = expcat_id
LEFT JOIN itemsite ON poitem_itemsite_id = itemsite_id
LEFT JOIN costcat ON itemsite_costcat_id = costcat_id

WHERE recv_invoiced = false 
AND trialbal_accnt_id IN (costcat_liability_accnt_id, expcat_liability_accnt_id)
  AND recv_vohead_id IS NULL AND recv_posted 
  AND recv_order_type = 'PO') -
(SELECT 
COALESCE(SUM( poreject_value), 0) 
  FROM poreject 
 JOIN poitem ON poreject_poitem_id = poitem_id
LEFT JOIN expcat ON poitem_expcat_id = expcat_id
LEFT JOIN itemsite ON poitem_itemsite_id = itemsite_id
LEFT JOIN costcat ON itemsite_costcat_id = costcat_id

  WHERE poreject_invoiced = false
AND trialbal_accnt_id IN (costcat_liability_accnt_id, expcat_liability_accnt_id)   
  AND poreject_vohead_id IS NULL 
  AND poreject_posted) 

  AS subledger

  FROM trialbal 
 WHERE trialbal_period_id  = (SELECT period_id FROM period WHERE current_date BETWEEN period_start AND period_end)
 AND trialbal_accnt_id IN (SELECT costcat_liability_accnt_id FROM costcat 
		UNION ALL SELECT expcat_liability_accnt_id FROM expcat)
 --GROUP BY ledger, subledger


 UNION ALL
-- Receivables
SELECT 'Receivables' AS ledger, 0 AS vseq,  sum(trialbal_ending * -1) AS glamount,
(SELECT 
SUM( CASE WHEN aropen_doctype IN ('I', 'D') THEN ROUND((aropen_amount - aropen_paid)/aropen_curr_rate,2)
ELSE ROUND((aropen_amount - aropen_paid)/aropen_curr_rate * -1,2) END) 
  FROM aropen WHERE aropen_open AND aropen_docdate <= period_end) AS subledger
     FROM trialbal
JOIN period ON current_date BETWEEN period_start AND period_end AND trialbal_period_id = period_id 
 WHERE  trialbal_accnt_id IN (SELECT araccnt_ar_accnt_id FROM araccnt 
		UNION ALL SELECT araccnt_deferred_accnt_id FROM araccnt)
 GROUP BY ledger, subledger

 UNION ALL
-- Receivables Account Detail
 
SELECT formatglaccountlong(trialbal_accnt_id) AS ledger, 1 AS vseq,  (trialbal_ending * -1) AS glamount,
(SELECT 
SUM( CASE WHEN aropen_doctype IN ('I', 'D') THEN ROUND((aropen_amount - aropen_paid)/aropen_curr_rate,2)
ELSE ROUND((aropen_amount - aropen_paid)/aropen_curr_rate * -1,2) END) 
  FROM aropen 
WHERE aropen_open AND aropen_docdate <= period_end
AND findaraccount(aropen_cust_id) = trialbal_accnt_id
AND aropen_doctype NOT IN ('R')
) AS subledger
     FROM trialbal
JOIN period ON current_date BETWEEN period_start AND period_end AND trialbal_period_id = period_id 
 WHERE  trialbal_accnt_id IN (SELECT araccnt_ar_accnt_id FROM araccnt 
	)

UNION ALL
 SELECT formatglaccountlong(trialbal_accnt_id) AS ledger, 1 AS vseq,  (trialbal_ending * -1) AS glamount,
(SELECT 
SUM( CASE WHEN aropen_doctype IN ('I', 'D') THEN ROUND((aropen_amount - aropen_paid)/aropen_curr_rate,2)
ELSE ROUND((aropen_amount - aropen_paid)/aropen_curr_rate * -1,2) END) 
  FROM aropen 
WHERE aropen_open AND aropen_docdate <= period_end
AND finddeferredaccount(aropen_cust_id) = trialbal_accnt_id
AND aropen_doctype IN ('R')
) AS subledger
     FROM trialbal
JOIN period ON current_date BETWEEN period_start AND period_end AND trialbal_period_id = period_id 
 WHERE  trialbal_accnt_id IN (SELECT araccnt_deferred_accnt_id FROM araccnt
		) 
 
UNION ALL
-- Inventory
SELECT 'Inventory' AS ledger, 0 AS vseq, SUM(trialbal_ending * -1) AS glamount,
(SELECT 
SUM( CASE itemsite_costmethod WHEN 'S' THEN
ROUND(itemsite_qtyonhand * stdcost(itemsite_item_id),2)
WHEN 'A' THEN 
ROUND(itemsite_value) ELSE 0 END) 
  FROM itemsite) AS subledger
  FROM trialbal 
 WHERE trialbal_period_id  = (SELECT period_id FROM period WHERE current_date BETWEEN period_start AND period_end)
 AND trialbal_accnt_id IN (SELECT costcat_asset_accnt_id FROM costcat )
 --GROUP BY ledger, subledger

UNION ALL
-- Inventory by Account
SELECT formatglaccountlong(trialbal_accnt_id) AS ledger, 1 AS vseq, (trialbal_ending * -1) AS glamount,
(SELECT 
SUM( CASE itemsite_costmethod WHEN 'S' THEN
ROUND(itemsite_qtyonhand * stdcost(itemsite_item_id),2)
WHEN 'A' THEN 
ROUND(itemsite_value) ELSE 0 END) 
  FROM itemsite
JOIN costcat ON itemsite_costcat_id = costcat_id
WHERE costcat_asset_accnt_id = trialbal_accnt_id
) AS subledger
  FROM trialbal 
 WHERE trialbal_period_id  = (SELECT period_id FROM period WHERE current_date BETWEEN period_start AND period_end)
 AND trialbal_accnt_id IN (SELECT costcat_asset_accnt_id FROM costcat )
 --GROUP BY ledger, subledger
 
UNION ALL
-- WIP
SELECT 'WIP' AS ledger, 0 AS vseq, sum(trialbal_ending * -1) AS glamount,
(SELECT 
SUM( round(wo_wipvalue,2) )FROM wo ) AS subledger
  FROM trialbal 
 WHERE trialbal_period_id  = (SELECT period_id FROM period WHERE current_date BETWEEN period_start AND period_end)
 AND trialbal_accnt_id IN (SELECT costcat_wip_accnt_id FROM costcat 
		)
 GROUP BY ledger, subledger


UNION ALL
-- WIP detail
SELECT formatglaccountlong(trialbal_accnt_id) AS ledger, 1 AS vseq, (trialbal_ending * -1) AS glamount,
(SELECT 
SUM( round(wo_wipvalue,2) )FROM wo 
JOIN itemsite on wo_itemsite_id = itemsite_id
JOIN costcat ON itemsite_costcat_id = costcat_id
WHERE costcat_wip_accnt_id = trialbal_accnt_id) AS subledger
  FROM trialbal 
 WHERE trialbal_period_id  = (SELECT period_id FROM period WHERE current_date BETWEEN period_start AND period_end)
 AND trialbal_accnt_id IN (SELECT costcat_wip_accnt_id FROM costcat 
		)
-- GROUP BY ledger, subledger
 
UNION ALL
-- Shipping Asset
SELECT 'Shipping Asset' AS ledger, 0 AS vseq, sum(trialbal_ending * -1) AS glamount,
(SELECT ROUND(COALESCE(SUM(shipitem_value), 0.0),2) 
  FROM shipitem JOIN shiphead ON (shipitem_shiphead_id=shiphead_id)
  WHERE NOT shiphead_shipped) AS subledger
  FROM trialbal 
 WHERE trialbal_period_id  = (SELECT period_id FROM period WHERE current_date BETWEEN period_start AND period_end)
 AND trialbal_accnt_id IN (SELECT costcat_shipasset_accnt_id FROM costcat )
GROUP BY ledger, subledger

UNION ALL

-- Shipping Asset detail
SELECT formatglaccountlong(trialbal_accnt_id) AS ledger, 1 AS vseq, (trialbal_ending * -1) AS glamount,
(SELECT ROUND(COALESCE(SUM(shipitem_value), 0.0),2) 
  FROM shipitem 
JOIN shiphead ON shipitem_shiphead_id=shiphead_id
JOIN invhist ON shipitem_invhist_id = invhist_id
JOIN itemsite on invhist_itemsite_id = itemsite_id
JOIN costcat ON itemsite_costcat_id = costcat_id
WHERE costcat_shipasset_accnt_id = trialbal_accnt_id
  AND NOT shiphead_shipped) AS subledger
  FROM trialbal 
 WHERE trialbal_period_id  = (SELECT period_id FROM period WHERE current_date BETWEEN period_start AND period_end)
 AND trialbal_accnt_id IN (SELECT costcat_shipasset_accnt_id FROM costcat )
 --GROUP BY ledger, subledger, vseq 
 ) AS ldata;

