posiciones <-function(n,altura,anchura,pte)
{
  x = 0
  y = 0
  res = data.frame()
  contador = "SN"
  for (i in 1:n)
  {
    print(contador)
    
    if(contador =="SN")
    {
      x = x
      y = y+1
      res = bind_rows(res,data.frame(x=x,y=y))
      
      if (y == altura){
        contador ="SA"
      }
      next
    }
    if(contador == "SA")
    {
      x = x+0.5
      y = y+0.5
      res = bind_rows(res,data.frame(x=x,y=y))
      if (y == altura + pte){
        contador = "DA"
      }
      next
    }
    if(contador == "DA")
    {
      x = x+0.5
      y = y-0.5
      res = bind_rows(res,data.frame(x=x,y=y))
      if (y == altura){
        contador = "DN"
      }
      next
    }
    if(contador == "DN")
    {
      x = x
      y = y-1
      res = bind_rows(res,data.frame(x=x,y=y))
      
      if (y == 0){
        contador ="DB"
      }
      next
      
    }
    if(contador =="DB")
    {
      x = x+0.5
      y = y-0.5
      res = bind_rows(res,data.frame(x=x,y=y))
      
      if (y == 0-pte){
        contador ="SB"
      }
      next
      
    }
    if(contador =="SB")
    {
      x = x+0.5
      y = y+0.5
      res = bind_rows(res,data.frame(x=x,y=y))
      
      if (y == 0){
        contador ="SN"
      }
      next
    }
  }
  return(res)
}
