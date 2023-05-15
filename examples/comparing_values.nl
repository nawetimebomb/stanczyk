;; The following program compares values using all the functionalities from the language.

;; Equality
!(5 4 - 3 2 * >) !nil ==
;; This evaluates to...
;; Left Side        ;; ;; Right Side  ;;
;; 5 - 4 = 1        ;; !nil = true    ;;
;; 3 * 2 = 6        ;;                ;;
;; 1 > 6 = false    ;;                ;;
;; !false = true    ;;                ;;
;;             true == true           ;;

;; String equality
"is equal" "is equal"  ==  ;; true
"different" "is equal" == ;; false
