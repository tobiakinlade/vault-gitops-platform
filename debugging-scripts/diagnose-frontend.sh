#!/bin/bash

echo "=== Frontend Connectivity Diagnostic ==="
echo ""

# 1. Check pods
echo "1. Frontend Pods:"
kubectl get pods -n tax-calculator -l component=frontend
echo ""

# 2. Check service
echo "2. Frontend Service:"
kubectl get svc frontend -n tax-calculator
echo ""

# 3. Check endpoints
echo "3. Service Endpoints:"
kubectl get endpoints frontend -n tax-calculator
echo ""

# 4. Check pod labels vs service selector
echo "4. Label Matching:"
echo "Pod labels:"
kubectl get pods -n tax-calculator -l component=frontend --show-labels | head -2
echo ""
echo "Service selector:"
kubectl get svc frontend -n tax-calculator -o jsonpath='{.spec.selector}'
echo ""
echo ""

# 5. Get frontend pod
FRONTEND_POD=$(kubectl get pods -n tax-calculator -l component=frontend -o jsonpath='{.items[0].metadata.name}')

if [ ! -z "$FRONTEND_POD" ]; then
  echo "5. Pod Details:"
  kubectl describe pod ${FRONTEND_POD} -n tax-calculator | grep -A 5 "Conditions:"
  echo ""
  
  echo "6. Recent Logs:"
  kubectl logs ${FRONTEND_POD} -n tax-calculator --tail=20
  echo ""
  
  echo "7. Test nginx config:"
  kubectl exec -n tax-calculator ${FRONTEND_POD} -- nginx -t 2>&1
  echo ""
  
  echo "8. Test backend connectivity from frontend:"
  kubectl exec -n tax-calculator ${FRONTEND_POD} -- curl -s -m 5 http://backend.tax-calculator.svc.cluster.local:8080/health || echo "Backend not reachable"
  echo ""
fi

# 9. Check LoadBalancer
echo "9. LoadBalancer URL:"
FRONTEND_URL=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "http://${FRONTEND_URL}"
echo ""

echo "10. Test LoadBalancer from your machine:"
curl -I -m 10 http://${FRONTEND_URL} 2>&1 || echo "LoadBalancer not accessible"
echo ""

echo "=== Diagnostic Complete ==="
