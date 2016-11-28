package frontend;

import java.util.*;
import scala.Tuple2;
import org.apache.spark.streaming.api.java.*;

public class HistoryData extends HistoryObject {

    // self defined parameters
    public double gamma = 0.8;
    public int precisionTime = 10;
    // end of self defined

    public HistoryData(JavaStreamingContext jssc) {
        super(jssc);
        windowSize = -1;
    }

   /*
    * implement this method for combination of old data and new data
    */
    public Tuple2<String, Map<String, List<Double>>> combineCall(Tuple2<String, Tuple2<
            Iterable<Map<String, List<Double>>>, Iterable<Map<String, List<Double>>>
            >> tuple2) {
        Map<String, List<Double>> oldData=null, newData=null;
        Iterator<Map<String, List<Double>>> iter;
        iter = tuple2._2()._1().iterator();
        if (iter.hasNext())
            newData = iter.next();
        iter = tuple2._2()._2().iterator();
        if (iter.hasNext())
            oldData = iter.next();
        if (newData != null) {
            // calculate the average for new records
            for (Map.Entry<String, List<Double>> entry : newData.entrySet()) {
                List<Double> scores = entry.getValue();
                double totalscore = 0;
                for (double score : scores)
                    totalscore += score;
                // here becomes 2-elements list: [sum, size]
                List<Double> countedScore = new ArrayList<>();
                countedScore.add(totalscore);
                countedScore.add((double)scores.size());
                entry.setValue(countedScore);
            }
            // combine the old data and new data
            if (oldData != null) {
                for (Map.Entry<String, List<Double>> oldEntry : oldData.entrySet()) {
                    List<Double> newValue = newData.get(oldEntry.getKey());
                    List<Double> oldValue = oldEntry.getValue();
                    if (newValue != null) {
                        newValue.set(0, newValue.get(0) + oldValue.get(0) * this.gamma);
                        newValue.set(1, newValue.get(1) + oldValue.get(1) * this.gamma);
                    } else {
                        newData.put(oldEntry.getKey(), oldValue);
                    }
                }
            }
            return new Tuple2(tuple2._1(), newData);
        } else {
            // discount the old data
            if (oldData != null) {
                for (Map.Entry<String, List<Double>> oldEntry : oldData.entrySet()) {
                    List<Double> oldValue = oldEntry.getValue();
                    oldValue.set(0, oldValue.get(0) * this.gamma);
                    oldValue.set(1, oldValue.get(1) * this.gamma);
                }
            }
            return new Tuple2(tuple2._1(), oldData);
        }
    }

    /*
     * implement this method for decision making
     */
    public String getDecision(Map<String, List<Double>> decisionStatMap) {
        // here is just a convert from List<Double> to double[]
        // the latter is much easier for process here
        Map<String, double[]> tmpMap = new HashMap<String, double[]>();
        for (Map.Entry<String, List<Double>> entry : decisionStatMap.entrySet()) {
            tmpMap.put(entry.getKey(), new double[]{entry.getValue().get(0), entry.getValue().get(1)});
        }
        double N = 0;
        for (Map.Entry<String, double[]> entry : tmpMap.entrySet()) {
            N += entry.getValue()[1];
            if (entry.getValue()[1] > 0)
                entry.getValue()[0] /= entry.getValue()[1];
            else
                entry.getValue()[0] = 0;
        }
        double score, maxScore;
        String bestDecision = "";
        String decisions = "";
        double[] bestDecisionInfo;
        double Bsqrt2logN = 0;
        for (int j = 0; j < precisionTime; j++) {
            maxScore = -Double.MAX_VALUE;
            Bsqrt2logN = 0;
            // if N <= 1, then it will be a negative number or zero.
            // in this case, we will not compute the Ct(y,i)
            if (N > 1)
                Bsqrt2logN = 1000 * Math.sqrt(2 * Math.log(N));
            for (Map.Entry<String, double[]> entry : tmpMap.entrySet()) {
                if (entry.getValue()[1] > 0)
                    score = entry.getValue()[0] + Bsqrt2logN / Math.sqrt(entry.getValue()[1]);
                else
                    score = 0;
                if (score > maxScore) {
                    bestDecision = entry.getKey();
                    maxScore = score;
                }
            }
            decisions += bestDecision + ":";
            bestDecisionInfo = tmpMap.get(bestDecision);
            bestDecisionInfo[1] += 1;
            N += 1;
            // discount for next precision
            N *= this.gamma;
            for (Map.Entry<String, double[]> entry : tmpMap.entrySet()) {
                 entry.getValue()[1] *= this.gamma;
            }
        }
        return decisions;
    }
}
